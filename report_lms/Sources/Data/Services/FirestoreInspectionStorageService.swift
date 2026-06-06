//
//  FirestoreInspectionStorageService.swift
//  report_lms
//

import Foundation
import OSLog
import FirebaseAuth

/// Firestore-backed implementation of `InspectionStorageServiceType`.
///
/// All reads are served from `cache` (fast, synchronous). `cache` is populated once
/// by `loadCache()` on app launch and updated in-place by every write operation.
///
/// ## Thread safety
/// `cache` is `@MainActor`-isolated. `isCacheLoaded` is a plain `Bool` written only
/// from `loadCache()` (which runs off the main actor) after the `MainActor.run` block
/// completes, then read on `@MainActor` in ViewModels — safe in practice because the
/// write happens exactly once before any ViewModel is created.
final class FirestoreInspectionStorageService: InspectionStorageServiceType {
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.reportlms.storage", category: "firestore")
    private let firestoreService: FirestoreService
    private let storageService: FirebaseStorageService
    private let deliveryQueueService: ReportDeliveryQueueService

    /// Flips to `true` when `loadCache()` finishes (success or failure).
    /// Stays `true` for the app lifetime; survives logout/login.
    private(set) var isCacheLoaded = false

    @MainActor
    private var cache: [Inspection] = []

    // MARK: - Initialization
    init(
        firestoreService: FirestoreService,
        storageService: FirebaseStorageService,
        deliveryQueueService: ReportDeliveryQueueService
    ) {
        self.firestoreService = firestoreService
        self.storageService = storageService
        self.deliveryQueueService = deliveryQueueService
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
            isCacheLoaded = true
            logger.log("Loaded \(inspections.count) inspections from Firestore")
            NotificationCenter.default.post(name: .inspectionCacheDidLoad, object: nil)
        } catch {
            logger.error("Failed to load from Firestore: \(error.localizedDescription)")
            isCacheLoaded = true
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
        NotificationCenter.default.post(name: .inspectionDidUpdate, object: nil)
        logger.log("Inspection updated in Firestore successfully")
    }

    /// Cascade delete: Firestore doc + cache + notification (blocking), then photos + delivery tasks (fire & forget).
    func deleteInspection(by id: String) async throws {
        logger.log("Cascade deleting inspection \(id)...")

        // 1. Fetch from cache first — need photo URLs before the doc is gone
        let inspection = await MainActor.run { cache.first { $0.id == id } }
        guard let inspection else {
            logger.error("Inspection \(id) not found in cache for deletion")
            throw InspectionStorageError.inspectionNotFound
        }

        // 2. Delete Firestore document (blocking)
        do {
            try await firestoreService.deleteInspection(id: id)
        } catch {
            logger.error("Firestore delete failed: \(error.localizedDescription)")
            throw InspectionStorageError.deleteFailed
        }

        // 3. Remove from cache + notify other tabs (blocking)
        await MainActor.run { cache.removeAll { $0.id == id } }
        NotificationCenter.default.post(name: .inspectionDidUpdate, object: nil)

        // 4. Fire & forget: delete photos + delivery queue tasks
        let photoURLs = inspection.sections
            .flatMap { $0.fields }
            .flatMap { field -> [String] in
                var urls = field.imageURLs
                if let url = field.photoURL { urls.append(url) }
                return urls
            }
            .filter { !$0.isEmpty }

        let storageService = self.storageService
        let deliveryQueueService = self.deliveryQueueService
        Task {
            for url in photoURLs {
                try? await storageService.deleteImage(fromURL: url)
            }
            if !photoURLs.isEmpty {
                logger.log("Deleted \(photoURLs.count) photos for inspection \(id)")
            }
            try? await deliveryQueueService.deleteTasksForInspection(inspectionId: id)
        }

        logger.log("Inspection \(id) cascade delete complete")
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
