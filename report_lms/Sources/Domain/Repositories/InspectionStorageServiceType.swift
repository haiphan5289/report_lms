//
//  InspectionStorageServiceType.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/6/26.
//

import Foundation

/// Protocol for local inspection storage with in-memory caching
protocol InspectionStorageServiceType {
    /// Load all inspections from disk into memory cache (call on app launch)
    func loadCache() async throws
    
    /// Get all cached inspections
    func getAllInspections() -> [Inspection]
    
    /// Get inspection by ID from cache
    func getInspection(by id: String) -> Inspection?
    
    /// Save a single inspection (updates cache and persists to disk)
    func saveInspection(_ inspection: Inspection) async throws
    
    /// Update an existing inspection (updates cache and persists to disk)
    func updateInspection(_ inspection: Inspection) async throws
    
    /// Delete inspection by ID (updates cache and persists to disk)
    func deleteInspection(by id: String) async throws
    
    /// Get draft inspections (status: plan or inProgress)
    func getDraftInspections() -> [Inspection]
    
    /// Get completed inspections (status: completed)
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
