//
//  PendingUploadStore.swift
//  report_lms
//

import Foundation

/// Tracks which locally-captured inspection images are waiting to be uploaded to Firebase Storage.
///
/// Keys: absolute file paths written by `InspectionImageCacheActor.cacheCapture`.
/// Stale paths (file deleted by iOS) are filtered out on every read.
///
/// Thread safety: `UserDefaults` is thread-safe; all methods are safe to call from any context.
final class PendingUploadStore {
    static let shared = PendingUploadStore()
    private let defaults = UserDefaults.standard
    private let inspectionIdsKey = "pendingUploadInspectionIds"

    private init() {}

    // MARK: - Write

    func addPending(filePath: String, inspectionId: String, fieldId: String) {
        var current = rawPaths(inspectionId: inspectionId, fieldId: fieldId)
        guard !current.contains(filePath) else { return }
        current.append(filePath)
        defaults.set(current, forKey: key(inspectionId: inspectionId, fieldId: fieldId))
        registerInspectionId(inspectionId)
        CacheDebugLogger.shared.log(.pendingAdded(fieldId: fieldId, count: current.count))
    }

    func clearField(inspectionId: String, fieldId: String) {
        defaults.removeObject(forKey: key(inspectionId: inspectionId, fieldId: fieldId))
    }

    /// Removes all pending entries for an inspection (call on eviction).
    func clearInspection(_ inspectionId: String) {
        let prefix = "pendingUploads_\(inspectionId)_"
        for k in defaults.dictionaryRepresentation().keys where k.hasPrefix(prefix) {
            defaults.removeObject(forKey: k)
        }
        var ids = defaults.stringArray(forKey: inspectionIdsKey) ?? []
        ids.removeAll { $0 == inspectionId }
        defaults.set(ids, forKey: inspectionIdsKey)
    }

    /// Returns all inspectionIds that have at least one registered pending upload.
    func getAllPendingInspectionIds() -> [String] {
        defaults.stringArray(forKey: inspectionIdsKey) ?? []
    }

    private func registerInspectionId(_ inspectionId: String) {
        var ids = defaults.stringArray(forKey: inspectionIdsKey) ?? []
        guard !ids.contains(inspectionId) else { return }
        ids.append(inspectionId)
        defaults.set(ids, forKey: inspectionIdsKey)
    }

    // MARK: - Read

    /// Returns paths that are still present on disk — stale entries are silently filtered.
    func getPendingFilePaths(inspectionId: String, fieldId: String) -> [String] {
        rawPaths(inspectionId: inspectionId, fieldId: fieldId)
            .filter { FileManager.default.fileExists(atPath: $0) }
    }

    func hasPending(inspectionId: String, fieldId: String) -> Bool {
        !getPendingFilePaths(inspectionId: inspectionId, fieldId: fieldId).isEmpty
    }

    /// Returns all (fieldId, filePaths) tuples for an inspection that still have pending uploads on disk.
    func getAllPendingFields(for inspectionId: String) -> [(fieldId: String, paths: [String])] {
        let prefix = "pendingUploads_\(inspectionId)_"
        let prefixLength = prefix.count
        return defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .compactMap { key -> (fieldId: String, paths: [String])? in
                let fieldId = String(key.dropFirst(prefixLength))
                let paths = (defaults.stringArray(forKey: key) ?? [])
                    .filter { FileManager.default.fileExists(atPath: $0) }
                return paths.isEmpty ? nil : (fieldId, paths)
            }
    }

    // MARK: - Private

    private func key(inspectionId: String, fieldId: String) -> String {
        "pendingUploads_\(inspectionId)_\(fieldId)"
    }

    private func rawPaths(inspectionId: String, fieldId: String) -> [String] {
        defaults.stringArray(forKey: key(inspectionId: inspectionId, fieldId: fieldId)) ?? []
    }
}
