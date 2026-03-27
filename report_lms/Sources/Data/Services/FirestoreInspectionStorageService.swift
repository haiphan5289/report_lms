//
//  FirestoreInspectionStorageService.swift
//  report_lms
//

import Foundation
import OSLog
import FirebaseAuth

/// Firestore-backed implementation of InspectionStorageServiceType.
/// Fetches from Firestore on loadCache(), then serves reads from an in-memory cache.
/// Writes are committed to Firestore first, then reflected in cache on success.
final class FirestoreInspectionStorageService: InspectionStorageServiceType {
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.reportlms.storage", category: "firestore")
    private let firestoreService: FirestoreService

    @MainActor
    private var cache: [Inspection] = []

    // MARK: - Initialization
    init(firestoreService: FirestoreService) {
        self.firestoreService = firestoreService
        logger.log("FirestoreInspectionStorageService initialized")
    }

    // MARK: - InspectionStorageServiceType

    /// Fetch all inspections from Firestore into the in-memory cache.
    /// Posts .inspectionCacheDidLoad on completion (success or failure).
    func loadCache() async throws {
        logger.log("Loading inspections from Firestore...")
        do {
            let inspections = try await firestoreService.fetchInspections()
            await MainActor.run { cache = inspections }
            logger.log("Loaded \(inspections.count) inspections from Firestore")
            NotificationCenter.default.post(name: .inspectionCacheDidLoad, object: nil)
        } catch {
            logger.error("Failed to load from Firestore: \(error.localizedDescription)")
            // Post notification so the UI doesn't hang indefinitely
            NotificationCenter.default.post(name: .inspectionCacheDidLoad, object: nil)
            throw InspectionStorageError.networkError
        }
    }

    @MainActor
    func getAllInspections() -> [Inspection] {
        cache
    }

    @MainActor
    func getInspection(by id: String) -> Inspection? {
        cache.first { $0.id == id }
    }

    /// Save to Firestore (setData = upsert), then update cache.
    func saveInspection(_ inspection: Inspection) async throws {
        logger.log("Auth.auth().currentUser?.uid \(KeychainManager.getStoredUsername() ?? "Unknown")")
        logger.log("Saving inspection \(inspection.inspectionNumber) to Firestore...")
        do {
            try await firestoreService.saveInspection(inspection)
        } catch {
            logger.error("Firestore save failed: \(error.localizedDescription)")
            throw InspectionStorageError.writeFailed
        }
        await MainActor.run {
            cache.removeAll { $0.id == inspection.id }
            cache.append(inspection)
        }
        logger.log("Inspection saved to Firestore successfully")
    }

    /// Update in Firestore (uses setData for safe upsert), then update cache.
    func updateInspection(_ inspection: Inspection) async throws {
        logger.log("Updating inspection \(inspection.inspectionNumber) in Firestore...")
        do {
            // Use saveInspection (setData) instead of updateData to avoid
            // failure when the document doesn't exist yet.
            try await firestoreService.saveInspection(inspection)
        } catch {
            logger.error("Firestore update failed: \(error.localizedDescription)")
            throw InspectionStorageError.writeFailed
        }
        await MainActor.run {
            if let index = cache.firstIndex(where: { $0.id == inspection.id }) {
                cache[index] = inspection
            } else {
                cache.append(inspection)
            }
        }
        logger.log("Inspection updated in Firestore successfully")
    }

    /// Delete from Firestore, then remove from cache.
    func deleteInspection(by id: String) async throws {
        logger.log("Deleting inspection \(id) from Firestore...")
        let exists = await MainActor.run { cache.contains { $0.id == id } }
        guard exists else {
            logger.error("Inspection \(id) not found in cache for deletion")
            throw InspectionStorageError.inspectionNotFound
        }
        do {
            try await firestoreService.deleteInspection(id: id)
        } catch {
            logger.error("Firestore delete failed: \(error.localizedDescription)")
            throw InspectionStorageError.deleteFailed
        }
        await MainActor.run { cache.removeAll { $0.id == id } }
        logger.log("Inspection deleted from Firestore successfully")
    }

    @MainActor
    func getDraftInspections() -> [Inspection] {
        cache.filter { $0.status == .plan || $0.status == .inProgress }
    }

    @MainActor
    func getCompletedInspections() -> [Inspection] {
        cache.filter { $0.status == .completed }
    }
}
