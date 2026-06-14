//
//  InspectionImageCacheActor.swift
//  report_lms
//

import UIKit
import OSLog

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

    // MARK: - Disk root (Documents — iOS will NOT purge this)

    private let baseURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("inspection-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Init

    private init() {}

    // MARK: - Local Capture → returns file path (stable key for PendingUploadStore)

    /// Writes a newly-captured `UIImage` to disk immediately and caches it in RAM.
    /// Returns the absolute file path, which callers should store in `PendingUploadStore`.
    func cacheCapture(image: UIImage, inspectionId: String, fieldId: String) async -> String? {
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

        // RAM — store thumbnail only; full-res lives on disk.
        // A 800px thumbnail is ~1.9 MB vs ~48 MB for a 12MP capture.
        let thumbForRAM = await Task.detached(priority: .userInitiated) {
            image.resizedIfNeeded(maxDimension: 800)
        }.value
        addToRAM(key: filePath, image: thumbForRAM)

        // Disk — write full-resolution JPEG so upload path reads original quality
        let data = await Task.detached(priority: .userInitiated) {
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

        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
            return UIImage(data: data)?.preparingForDisplay()
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
        let dir = fieldURL(inspectionId: inspectionId, fieldId: fieldId)
        let fileURL = dir.appendingPathComponent("remote_\(key).jpg")

        addToRAM(key: fileURL.path, image: image)

        let data = await Task.detached(priority: .background) {
            image.jpegData(compressionQuality: 0.85)
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

        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? Data(contentsOf: fileURL) else { return nil }
            return UIImage(data: data)?.preparingForDisplay()
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
        // Hash the full stable URL — compact, unique per image, no truncation collisions.
        // (addingPercentEncoding+prefix(80) would collide for all Firebase URLs sharing the same domain prefix.)
        return String(stable.hashValue & 0x7FFFFFFFFFFFFFFF, radix: 16)
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
