//
//  InspectionStorageServiceType.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/6/26.
//

import Foundation

/// Protocol for local inspection storage with in-memory caching.
///
/// ## Cache lifecycle
///
/// 1. App launches → caller invokes `loadCache()` once → populates in-memory cache
///    and posts `.inspectionCacheDidLoad`.
/// 2. `isCacheLoaded` flips to `true` on completion (success *or* failure) and stays
///    `true` for the lifetime of the singleton — surviving logout/login cycles.
/// 3. ViewModels observe `.inspectionCacheDidLoad` for the initial load, and check
///    `isCacheLoaded` at creation to handle re-login (notification already fired).
protocol InspectionStorageServiceType {
    /// `true` once `loadCache()` has completed at least once.
    ///
    /// Remains `true` after logout/login because the service is a singleton.
    /// ViewModels use this to detect "cache already ready" when they are created
    /// after the initial `.inspectionCacheDidLoad` notification has already fired.
    var isCacheLoaded: Bool { get }

    /// Populate the in-memory cache from the backing store (Firestore or local disk),
    /// scoped to `inspectorId` so one user never sees another user's inspections.
    ///
    /// - Call once the signed-in user's id is known (after login, or after
    ///   Firebase Auth restores a persisted session).
    /// - Always posts `.inspectionCacheDidLoad` on both success and failure so the
    ///   UI is never left waiting indefinitely.
    func loadCache(inspectorId: String) async throws

    /// Returns all inspections currently held in the in-memory cache.
    func getAllInspections() -> [Inspection]

    /// Returns the inspection with the given `id`, or `nil` if not cached.
    func getInspection(by id: String) -> Inspection?

    /// Persists `inspection` to the backing store and updates the cache.
    func saveInspection(_ inspection: Inspection) async throws

    /// Overwrites the stored copy of `inspection` and refreshes the cache.
    func updateInspection(_ inspection: Inspection) async throws

    /// Updates `imageURLs`, `imageDescriptions`, `imageMeasurementsMM`, and (optionally) `comment`
    /// for a single field without replacing the entire document.
    ///
    /// Concurrent field uploads (two fields uploading simultaneously) would otherwise
    /// race: each reads the same Firestore snapshot, updates only its own field, then
    /// `setData` — the second write silently erases the first field's URLs. This method
    /// serializes those writes so each one reads a fresh snapshot after the previous
    /// write lands, guaranteeing both fields' URLs survive.
    ///
    /// - Parameter comment: pass `nil` to leave the field's stored comment untouched (e.g. the
    ///   pending-upload retry path, which has no comment context); pass a value — including an
    ///   empty string — to overwrite it with the inspector's current text.
    @MainActor
    func updateFieldImageURLs(inspectionId: String, fieldId: String, imageURLs: [String], imageDescriptions: [String], imageMeasurementsMM: [String], comment: String?) async throws

    /// Updates only the `status` field — safe to call concurrently with `updateFieldImageURLs`.
    ///
    /// Unlike `updateInspection` (full document write), this method does a partial update
    /// so it cannot overwrite `imageURLs` written by concurrent field uploads.
    func updateInspectionStatus(inspectionId: String, status: InspectionStatus) async throws

    /// Removes the inspection with `id` from both the backing store and the cache.
    func deleteInspection(by id: String) async throws

    /// Returns inspections whose status is `.plan` or `.inProgress`.
    func getDraftInspections() -> [Inspection]

    /// Returns inspections whose status is `.completed`.
    func getCompletedInspections() -> [Inspection]
}

extension InspectionStorageServiceType {
    /// Convenience overload for call sites that have no per-image descriptions or comment
    /// context (e.g. retry service) — leaves the stored `comment` untouched.
    @MainActor
    func updateFieldImageURLs(inspectionId: String, fieldId: String, imageURLs: [String]) async throws {
        try await updateFieldImageURLs(inspectionId: inspectionId, fieldId: fieldId, imageURLs: imageURLs, imageDescriptions: [], imageMeasurementsMM: [], comment: nil)
    }
}

/// Storage errors
enum InspectionStorageError: LocalizedError {
    case fileNotFound
    case encodingFailed
    case decodingFailed
    case writeFailed
    case deleteFailed
    case inspectionNotFound
    case networkError

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Không tìm thấy file dữ liệu"
        case .encodingFailed:
            return "Không thể mã hóa dữ liệu"
        case .decodingFailed:
            return "Không thể giải mã dữ liệu"
        case .writeFailed:
            return "Không thể ghi file"
        case .deleteFailed:
            return "Không thể xóa dữ liệu"
        case .inspectionNotFound:
            return "Không tìm thấy báo cáo kiểm tra"
        case .networkError:
            return "Không thể kết nối đến máy chủ"
        }
    }
}
