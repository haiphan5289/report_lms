//
//  PendingErrorUploadStore.swift
//  report_lms
//

import Foundation

/// Metadata needed to retry a `saveErrorItem` call from scratch — the images themselves
/// live in `LocalImageStore` (Documents/pending-uploads/{userId}/{itemId}/), keyed by `itemId`.
///
/// Unlike `PendingUploadStore` (inspection field images, which only ever need a partial
/// `updateFieldImageURLs` merge onto an existing doc), an error item's Firestore doc may not
/// exist at all yet if the app is killed before the first `saveErrorItem` succeeds — so the
/// full item metadata must be persisted, not just file paths.
struct PendingErrorUpload: Codable {
    let inspectionId: String
    let itemId: String
    let severityRaw: String
    let generalCondition: Int?
    let defectTypeRaw: String?
    let comments: String
    let imageNotes: [String]
    let existingRemoteURLs: [String]
    let createdAtISO: String
}

/// Tracks error items whose photos/metadata are saved locally but not yet confirmed on
/// Firestore + Firebase Storage. Read by `PendingUploadRetryService` at app launch.
///
/// Thread safety: `UserDefaults` is thread-safe; all methods are safe to call from any context.
final class PendingErrorUploadStore {
    static let shared = PendingErrorUploadStore()
    private let defaults = UserDefaults.standard
    private let itemIdsKey = "pendingErrorUploadItemIds"

    private init() {}

    // MARK: - Write

    func addPending(_ upload: PendingErrorUpload) {
        guard let data = try? JSONEncoder().encode(upload) else { return }
        defaults.set(data, forKey: key(itemId: upload.itemId))
        registerItemId(upload.itemId)
    }

    func clearPending(itemId: String) {
        defaults.removeObject(forKey: key(itemId: itemId))
        var ids = defaults.stringArray(forKey: itemIdsKey) ?? []
        ids.removeAll { $0 == itemId }
        defaults.set(ids, forKey: itemIdsKey)
    }

    // MARK: - Read

    /// Returns every pending upload still registered. Stale entries (decode failure) are dropped.
    func getAllPending() -> [PendingErrorUpload] {
        let ids = defaults.stringArray(forKey: itemIdsKey) ?? []
        return ids.compactMap { itemId -> PendingErrorUpload? in
            guard let data = defaults.data(forKey: key(itemId: itemId)) else { return nil }
            return try? JSONDecoder().decode(PendingErrorUpload.self, from: data)
        }
    }

    // MARK: - Private

    private func registerItemId(_ itemId: String) {
        var ids = defaults.stringArray(forKey: itemIdsKey) ?? []
        guard !ids.contains(itemId) else { return }
        ids.append(itemId)
        defaults.set(ids, forKey: itemIdsKey)
    }

    private func key(itemId: String) -> String {
        "pendingErrorUpload_\(itemId)"
    }
}
