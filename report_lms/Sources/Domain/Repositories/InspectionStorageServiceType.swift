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

    /// Populate the in-memory cache from the backing store (Firestore or local disk).
    ///
    /// - Call once at app launch from `App.init()`.
    /// - Always posts `.inspectionCacheDidLoad` on both success and failure so the
    ///   UI is never left waiting indefinitely.
    func loadCache() async throws

    /// Returns all inspections currently held in the in-memory cache.
    func getAllInspections() -> [Inspection]

    /// Returns the inspection with the given `id`, or `nil` if not cached.
    func getInspection(by id: String) -> Inspection?

    /// Persists `inspection` to the backing store and updates the cache.
    func saveInspection(_ inspection: Inspection) async throws

    /// Overwrites the stored copy of `inspection` and refreshes the cache.
    func updateInspection(_ inspection: Inspection) async throws

    /// Removes the inspection with `id` from both the backing store and the cache.
    func deleteInspection(by id: String) async throws

    /// Returns inspections whose status is `.plan` or `.inProgress`.
    func getDraftInspections() -> [Inspection]

    /// Returns inspections whose status is `.completed`.
    func getCompletedInspections() -> [Inspection]
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
