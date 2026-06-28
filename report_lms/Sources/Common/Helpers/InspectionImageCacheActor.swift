//
//  InspectionImageCacheActor.swift
//  report_lms
//

import CryptoKit
import OSLog
import UIKit

/// Durable RAM + disk cache for inspection photos.
///
/// - Disk root: `Documents/inspection-images/<inspectionId>/<fieldId>/`
/// - Local captures are stored by UUID filename; remote images are keyed by a URL hash.
/// - Eviction is inspection-scoped: call `evictInspection(_:)` when an inspection
///   is completed or deleted to reclaim disk space.
actor InspectionImageCacheActor {
    static let shared = InspectionImageCacheActor()

    private let logger = Logger(subsystem: "com.reportlms", category: "InspectionImageCache")

    // MARK: - RAM layer (bounded to 60 entries by FIFO eviction)

    private var ram: [String: UIImage] = [:]
    private var insertionOrder: [String] = []
    private let maxRAMCount = 60
    private var promotingKeys: Set<String> = []

    // MARK: - Disk root (Documents — iOS will NOT purge this)

    private let baseURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("inspection-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Init

    private init() {
        // Singleton lives for the app's lifetime — observer token is intentionally discarded.
        _ = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            Task { await self.evictAllRAM() }
        }
    }

    // MARK: - Local Capture → returns file path (stable key for PendingUploadStore)

    /// Writes a newly-captured `UIImage` to disk immediately and caches a thumbnail in RAM.
    /// - Parameter thumbnail: pre-resized thumbnail from Phase 1 (avoids a second resize).
    ///   If nil, falls back to resizing `image` to 800px.
    /// Returns the absolute file path, which callers should store in `PendingUploadStore`.
    func cacheCapture(image: UIImage, thumbnail: UIImage? = nil, inspectionId: String, fieldId: String) async -> String? {
        let dir = fieldURL(inspectionId: inspectionId, fieldId: fieldId)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create dir: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        let fileName = "capture_\(UUID().uuidString).jpg"
        let fileURL = dir.appendingPathComponent(fileName)
        let filePath = fileURL.path

        // RAM — reuse the thumbnail already computed in Phase 1 when available,
        // otherwise resize here. Avoids re-resizing a 12MP image a second time.
        let thumbForRAM: UIImage
        if let provided = thumbnail {
            thumbForRAM = provided
        } else {
            // .utility: batch capture path — lower priority lets the system manage thermal budget.
            thumbForRAM = await Task.detached(priority: .utility) {
                image.resizedIfNeeded(maxDimension: 800)
            }.value
        }
        addToRAM(key: filePath, image: thumbForRAM)

        // Disk — write full-resolution JPEG so upload path reads original quality.
        // .utility: 300 sequential encodes at .userInitiated sustained thermal overload.
        let data = await Task.detached(priority: .utility) {
            image.jpegData(compressionQuality: 0.85)
        }.value

        guard let data else {
            logger.error("JPEG compress failed for capture \(fileName, privacy: .public)")
            return nil
        }

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Disk write failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }

        CacheDebugLogger.shared.log(.diskWrite(tag: fileName, sizeKB: data.count / 1024))
        logger.debug("Capture cached: \(filePath, privacy: .public)")
        return filePath
    }

    // MARK: - Load from absolute path (pending-upload retry)

    func loadFromPath(_ path: String) async -> UIImage? {
        if let cached = ram[path] {
            CacheDebugLogger.shared.log(.ramHit(tag: (path as NSString).lastPathComponent))
            return cached
        }

        // Disk file is full-res JPEG (~48 MB decoded). Resize to 800px before storing in RAM
        // so this path matches the thumbnail size produced by Phase 1 / cacheCapture.
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let full = UIImage(data: data) else { return nil }
            let resized = full.resizedIfNeeded(maxDimension: 800)
            return resized.preparingForDisplay() ?? resized
        }.value

        if let image {
            addToRAM(key: path, image: image)
            CacheDebugLogger.shared.log(.diskHit(tag: (path as NSString).lastPathComponent))
        }
        return image
    }

    // MARK: - Remote Image by URL (durable display cache after upload)

    /// Called after upload succeeds so the next session can display instantly without Firebase.
    func cacheRemote(image: UIImage, url: URL, inspectionId: String, fieldId: String) async {
        let key = remoteKey(for: url)
        // Guard against redundant concurrent calls for the same URL (e.g. multiple cells
        // for the same image all hitting ImageCacheActor and each launching a promote task).
        // Since actor calls are serialised, the second caller sees the key already present.
        guard !promotingKeys.contains(key) else { return }
        promotingKeys.insert(key)
        defer { promotingKeys.remove(key) }

        let dir = fieldURL(inspectionId: inspectionId, fieldId: fieldId)
        let fileURL = dir.appendingPathComponent("remote_\(key).jpg")

        // Resize to 1024px max before RAM — remote images from Firebase can be full-res
        // (e.g. 3024×4032 = ~46 MB decoded). 1024px cap ≈ 4 MB per entry.
        let display = await Task.detached(priority: .userInitiated) { () -> UIImage in
            let resized = image.resizedIfNeeded(maxDimension: 1024)
            return resized.preparingForDisplay() ?? resized
        }.value
        addToRAM(key: fileURL.path, image: display)

        let data = await Task.detached(priority: .background) {
            display.jpegData(compressionQuality: 0.85)
        }.value

        guard let data else { return }

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
        logger.debug("Remote cached: \(url.lastPathComponent, privacy: .public)")
    }

    /// Checks docs-dir for a pre-cached remote image before hitting the network.
    func loadRemote(url: URL, inspectionId: String, fieldId: String) async -> UIImage? {
        let key = remoteKey(for: url)
        let fileURL = fieldURL(inspectionId: inspectionId, fieldId: fieldId)
            .appendingPathComponent("remote_\(key).jpg")
        let filePath = fileURL.path

        if let cached = ram[filePath] {
            CacheDebugLogger.shared.log(.ramHit(tag: url.lastPathComponent))
            return cached
        }

        // Disk file was written by cacheRemote at 1024px — reload and resize defensively
        // in case a future caller writes a larger variant to the same path.
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? Data(contentsOf: fileURL),
                  let full = UIImage(data: data) else { return nil }
            let resized = full.resizedIfNeeded(maxDimension: 1024)
            return resized.preparingForDisplay() ?? resized
        }.value

        if let image {
            addToRAM(key: filePath, image: image)
            CacheDebugLogger.shared.log(.diskHit(tag: url.lastPathComponent))
        }
        return image
    }

    // MARK: - Eviction

    /// Removes all cached images (RAM + disk) for an inspection.
    /// Call when inspection is completed or deleted.
    func evictInspection(_ inspectionId: String) async {
        let inspDir = baseURL.appendingPathComponent(inspectionId, isDirectory: true)
        let prefix = inspDir.path

        // RAM eviction
        let keysToRemove = ram.keys.filter { $0.hasPrefix(prefix) }
        keysToRemove.forEach { ram.removeValue(forKey: $0) }
        insertionOrder.removeAll { keysToRemove.contains($0) }

        // Disk eviction
        try? FileManager.default.removeItem(at: inspDir)

        CacheDebugLogger.shared.log(.evicted(inspectionId: inspectionId))
        logger.log("Evicted inspection \(inspectionId, privacy: .public) from InspectionImageCacheActor")
    }

    /// Clears all RAM thumbnails in response to a memory warning.
    /// Disk images are untouched — next display will reload from disk transparently.
    func evictAllRAM() {
        let count = ram.count
        ram.removeAll()
        insertionOrder.removeAll()
        logger.warning("Memory warning: evicted \(count, privacy: .public) RAM entries (~\(count * 2, privacy: .public) MB freed)")
    }

    // MARK: - Debug stats

    func stats(inspectionId: String, fieldId: String) async -> (ram: Int, disk: Int) {
        let dir = fieldURL(inspectionId: inspectionId, fieldId: fieldId)
        let ramCount = ram.keys.filter { $0.hasPrefix(dir.path) }.count
        // Offload disk I/O so it doesn't block the actor executor for other awaiting calls.
        let diskPath = dir.path
        let diskFiles = await Task.detached(priority: .background) {
            (try? FileManager.default.contentsOfDirectory(atPath: diskPath)) ?? []
        }.value
        return (ramCount, diskFiles.count)
    }

    // MARK: - Private helpers

    private func fieldURL(inspectionId: String, fieldId: String) -> URL {
        baseURL
            .appendingPathComponent(inspectionId, isDirectory: true)
            .appendingPathComponent(fieldId, isDirectory: true)
    }

    private func remoteKey(for url: URL) -> String {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        comps?.query = nil  // strip signed token — key is stable across URL rotations
        let stable = comps?.string ?? url.absoluteString
        // SHA256 prefix — deterministic across process restarts.
        // Swift's hashValue is seed-randomised per process, so it must NOT be used as a
        // persistent file name (every restart produces a different key → cache miss forever).
        guard let data = stable.data(using: .utf8) else { return url.lastPathComponent }
        return SHA256.hash(data: data)
            .prefix(16)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func addToRAM(key: String, image: UIImage) {
        if ram.count >= maxRAMCount {
            let half = maxRAMCount / 2
            let toRemove = Array(insertionOrder.prefix(half))
            toRemove.forEach { ram.removeValue(forKey: $0) }
            insertionOrder.removeFirst(min(half, insertionOrder.count))
        }
        if ram[key] == nil { insertionOrder.append(key) }
        ram[key] = image
    }
}
