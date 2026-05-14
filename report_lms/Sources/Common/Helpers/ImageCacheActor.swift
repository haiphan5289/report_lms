//
//  ImageCacheActor.swift
//  report_lms
//

import UIKit
import os

actor ImageCacheActor {
    static let shared = ImageCacheActor()

    private let logger = Logger(subsystem: "report_lms", category: "ImageCache")

    // MARK: - RAM

    private var ram: [String: UIImage] = [:]
    private var insertionOrder: [String] = []
    private let maxRAMCount = 100

    // MARK: - Disk

    private let diskURL: URL = {
        let base = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("img_cache_v1", isDirectory: true)
    }()

    private init() {
        try? FileManager.default.createDirectory(at: diskURL, withIntermediateDirectories: true)
    }

    // MARK: - Read

    func image(for url: URL) async -> UIImage? {
        let key = stableKey(url)

        if let img = ram[key] { return img }

        let file = diskURL.appendingPathComponent(key)

        // Disk read + decode off the actor's executor so other callers aren't starved.
        let img = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? Data(contentsOf: file) else { return nil }
            return UIImage(data: data)?.preparingForDisplay()
        }.value

        guard let img else { return nil }
        addToRAM(key: key, image: img)
        logger.debug("Disk hit: \(key, privacy: .public)")
        return img
    }

    // MARK: - Write

    func store(_ image: UIImage, for url: URL) {
        let key = stableKey(url)
        addToRAM(key: key, image: image)

        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        let file = diskURL.appendingPathComponent(key)
        let logger = self.logger

        // Disk write off the actor's executor — actor is free immediately after.
        Task.detached(priority: .background) {
            do {
                try data.write(to: file, options: .atomic)
            } catch {
                logger.error("Disk write failed for \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Evict

    func clearAll() {
        ram.removeAll()
        insertionOrder.removeAll()
        do {
            try FileManager.default.removeItem(at: diskURL)
            try FileManager.default.createDirectory(at: diskURL, withIntermediateDirectories: true)
        } catch {
            logger.error("Cache clear failed: \(error.localizedDescription, privacy: .public)")
        }
        logger.debug("Cache cleared")
    }

    // MARK: - Helpers

    private func addToRAM(key: String, image: UIImage) {
        evictRAMIfNeeded()
        if ram[key] == nil {
            insertionOrder.append(key)
        }
        ram[key] = image
    }

    private func evictRAMIfNeeded() {
        guard ram.count >= maxRAMCount else { return }
        let half = ram.count / 2
        let toRemove = insertionOrder.prefix(half)
        toRemove.forEach { ram.removeValue(forKey: $0) }
        insertionOrder.removeFirst(half)
        logger.debug("RAM evicted \(half) entries")
    }

    /// Strips Firebase Storage signed URL query params so the key stays stable
    /// even when the auth token rotates.
    private func stableKey(_ url: URL) -> String {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        comps?.query = nil
        let stable = comps?.string ?? url.absoluteString
        return stable
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics)
            ?? url.lastPathComponent
    }
}
