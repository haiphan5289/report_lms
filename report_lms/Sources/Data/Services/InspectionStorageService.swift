//
//  InspectionStorageService.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/6/26.
//

import Foundation
import OSLog

/// Notification posted when cache finishes loading
extension Notification.Name {
    static let inspectionCacheDidLoad = Notification.Name("inspectionCacheDidLoad")
    static let inspectionDidUpdate = Notification.Name("inspectionDidUpdate")
    /// Posted when an inspection is marked completed; userInfo["inspectionId"] = String
    static let navigateToReportTab = Notification.Name("navigateToReportTab")
}

/// Local-disk implementation of `InspectionStorageServiceType`.
///
/// Persists all inspections as a single JSON file at `Documents/inspections.json`.
/// Reads are served from `cache` after `loadCache()` completes.
final class InspectionStorageService: InspectionStorageServiceType {
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.reportlms.storage", category: "inspection")
    private let fileManager = FileManager.default
    private let fileName = "inspections.json"

    /// Flips to `true` when `loadCache()` finishes (success or failure).
    /// Stays `true` for the app lifetime; survives logout/login.
    private(set) var isCacheLoaded = false

    /// In-memory cache for fast access
    @MainActor
    private var cache: [Inspection] = []
    
    /// File URL for inspections.json in Documents directory
    private var fileURL: URL {
        get throws {
            let documentsDirectory = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return documentsDirectory.appendingPathComponent(fileName)
        }
    }
    
    // MARK: - Initialization
    init() {
        logger.log("InspectionStorageService initialized")
    }
    
    // MARK: - Public Methods
    
    /// Load all inspections from disk into memory cache
    /// Should be called on app launch
    func loadCache() async throws {
        logger.log("Loading inspections cache from disk...")
        
        do {
            let url = try fileURL
            
            // Check if file exists
            guard fileManager.fileExists(atPath: url.path) else {
                logger.log("No existing inspections file, starting with empty cache")
                await MainActor.run {
                    cache = []
                }
                isCacheLoaded = true
                NotificationCenter.default.post(name: .inspectionCacheDidLoad, object: nil)
                return
            }
            
            // Read and decode
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let inspections = try decoder.decode([Inspection].self, from: data)
            
            await MainActor.run {
                cache = inspections
            }
            
            logger.log("Loaded \(inspections.count) inspections into cache")
            isCacheLoaded = true
            NotificationCenter.default.post(name: .inspectionCacheDidLoad, object: nil)
        } catch {
            logger.error("Failed to load cache: \(error.localizedDescription)")
            logger.record(error)
            throw InspectionStorageError.decodingFailed
        }
    }
    
    /// Get all cached inspections
    @MainActor
    func getAllInspections() -> [Inspection] {
        cache
    }
    
    /// Get inspection by ID from cache
    @MainActor
    func getInspection(by id: String) -> Inspection? {
        cache.first { $0.id == id }
    }
    
    /// Save a new inspection (adds to cache and persists)
    func saveInspection(_ inspection: Inspection) async throws {
        logger.log("Saving inspection #\(inspection.inspectionNumber)...")
        
        // Add to cache
        await MainActor.run {
            // Remove existing if duplicate ID (update case)
            cache.removeAll { $0.id == inspection.id }
            cache.append(inspection)
        }
        
        // Persist to disk
        try await persistCache()
        
        logger.log("Inspection saved successfully")
    }
    
    /// Update an existing inspection (updates cache and persists)
    func updateInspection(_ inspection: Inspection) async throws {
        logger.log("Updating inspection #\(inspection.inspectionNumber)...")
        
        await MainActor.run {
            if let index = cache.firstIndex(where: { $0.id == inspection.id }) {
                cache[index] = inspection
            } else {
                // If not found, add it (fallback)
                cache.append(inspection)
            }
        }
        
        try await persistCache()
        
        logger.log("Inspection updated successfully")
    }
    
    @MainActor
    func updateFieldImageURLs(inspectionId: String, fieldId: String, imageURLs: [String]) async throws {
        guard var inspection = getInspection(by: inspectionId) else { return }
        for si in inspection.sections.indices {
            if let fi = inspection.sections[si].fields.firstIndex(where: { $0.id == fieldId }) {
                inspection.sections[si].fields[fi].imageURLs = imageURLs
                inspection.sections[si].fields[fi].photoURL = imageURLs.first
                break
            }
        }
        try await updateInspection(inspection)
    }

    /// Partial update — only touches `status` in cache + disk (no imageURLs overwrite risk).
    func updateInspectionStatus(inspectionId: String, status: InspectionStatus) async throws {
        await MainActor.run {
            if let index = cache.firstIndex(where: { $0.id == inspectionId }) {
                cache[index].status = status
            }
        }
        try await persistCache()
        logger.log("Inspection \(inspectionId) status updated to \(status.rawValue)")
    }

    /// Delete inspection by ID (removes from cache and persists)
    func deleteInspection(by id: String) async throws {
        logger.log("Deleting inspection with ID: \(id)...")

        let removed = await MainActor.run { () -> Bool in
            let countBefore = cache.count
            cache.removeAll { $0.id == id }
            return cache.count < countBefore
        }

        guard removed else {
            logger.error("Inspection not found for deletion")
            throw InspectionStorageError.inspectionNotFound
        }

        try await persistCache()

        // Evict durable image cache + pending upload set
        Task.detached(priority: .background) {
            await InspectionImageCacheActor.shared.evictInspection(id)
            PendingUploadStore.shared.clearInspection(id)
        }

        logger.log("Inspection deleted successfully")
    }
    
    /// Get draft inspections (not completed yet)
    @MainActor
    func getDraftInspections() -> [Inspection] {
        cache.filter { $0.status == .plan || $0.status == .inProgress }
    }
    
    /// Get completed inspections
    @MainActor
    func getCompletedInspections() -> [Inspection] {
        cache.filter { $0.status == .completed }
    }
    
    // MARK: - Private Methods
    
    /// Persist current cache to disk
    private func persistCache() async throws {
        let inspections = await MainActor.run {
            cache
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let data = try encoder.encode(inspections)
            let url = try fileURL
            
            try data.write(to: url, options: .atomic)
            
            logger.log("Persisted \(inspections.count) inspections to disk")
        } catch {
            logger.error("Failed to persist cache: \(error.localizedDescription)")
            logger.record(error)
            throw InspectionStorageError.writeFailed
        }
    }
}
