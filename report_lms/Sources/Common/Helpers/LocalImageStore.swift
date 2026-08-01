//
//  LocalImageStore.swift
//  report_lms
//
//  Created by Hai Phan on 8/6/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import UIKit
import FirebaseAuth

/// Persists UIImages to Documents/pending-uploads/{userId}/{itemId}/{index}_{UUID}.jpg
/// Each user gets their own namespace; each image gets a UUID filename to avoid collisions.
///
/// Uses `.documentDirectory` (not `.cachesDirectory`) so pending error-item photos survive
/// OS low-storage cache eviction until `ErrorItemUploadCoordinator` confirms the upload
/// succeeded and clears them — mirrors `InspectionImageCacheActor`'s durability guarantee.
actor LocalImageStore {
    static let shared = LocalImageStore()

    private let baseURL: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pending-uploads", isDirectory: true)
    }()

    private var currentUserId: String {
        Auth.auth().currentUser?.uid ?? "anonymous"
    }

    // MARK: - Save

    /// Saves images to disk, returns the file URLs in order.
    func save(_ images: [UIImage], for itemId: String) async throws -> [URL] {
        let folder = folderURL(for: itemId)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var urls: [URL] = []
        for (index, image) in images.enumerated() {
            let fileName = "\(index)_\(UUID().uuidString).jpg"
            let fileURL = folder.appendingPathComponent(fileName)
            let data = await Task.detached(priority: .userInitiated) {
                image.prepareForUpload(maxDimension: 1600, compressionQuality: 0.85)
            }.value
            guard let data else { continue }
            try data.write(to: fileURL, options: .atomic)
            urls.append(fileURL)
        }
        return urls
    }

    // MARK: - Load

    /// Loads images from disk in index order. Returns [] if folder doesn't exist.
    func load(for itemId: String) -> [UIImage] {
        let folder = folderURL(for: itemId)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        ) else { return [] }
        return files
            .filter { $0.pathExtension == "jpg" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { UIImage(contentsOfFile: $0.path) }
    }

    // MARK: - Existence Check

    func hasImages(for itemId: String) -> Bool {
        let folder = folderURL(for: itemId)
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return files.contains { $0.hasSuffix(".jpg") }
    }

    // MARK: - Clear

    func clear(for itemId: String) {
        try? FileManager.default.removeItem(at: folderURL(for: itemId))
    }

    // MARK: - Private

    private func folderURL(for itemId: String) -> URL {
        baseURL
            .appendingPathComponent(currentUserId, isDirectory: true)
            .appendingPathComponent(itemId, isDirectory: true)
    }
}
