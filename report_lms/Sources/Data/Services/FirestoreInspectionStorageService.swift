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

    /// Tail of the serial write chain for field-level image URL updates.
    /// New writes chain onto this task so reads always see the previous write's result.
    @MainActor
    private var pendingFieldWrite: Task<Void, Error>?

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
    func loadCache(companyId: String) async throws {
        logger.log("Loading inspections from Firestore for company \(companyId)...")
        do {
            let inspections = try await firestoreService.fetchInspections(companyId: companyId)
            await MainActor.run { cache = inspections }
            isCacheLoaded = true
            logger.log("Loaded \(inspections.count) inspections from Firestore")
            NotificationCenter.default.post(name: .inspectionCacheDidLoad, object: nil)
        } catch {
            logger.error("Failed to load from Firestore: \(error.localizedDescription)")
            logger.record(error)
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
            logger.record(error)
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
            logger.record(error)
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

    /// Serialized field-level write: chains onto any in-flight write so the read always
    /// sees the previous write's result, preventing concurrent uploads from overwriting
    /// each other's imageURLs via last-writer-wins `setData`.
    @MainActor
    func updateFieldImageURLs(inspectionId: String, fieldId: String, imageURLs: [String], imageDescriptions: [String], imageMeasurementsMM: [String]) async throws {
        let previous = pendingFieldWrite
        let newTask = Task { @MainActor in
            // Wait for any in-flight write to land before reading cache.
            // Ignore the previous task's error — our write should still proceed.
            _ = try? await previous?.value

            guard var inspection = self.getInspection(by: inspectionId) else { return }
            for si in inspection.sections.indices {
                if let fi = inspection.sections[si].fields.firstIndex(where: { $0.id == fieldId }) {
                    inspection.sections[si].fields[fi].imageURLs = imageURLs
                    inspection.sections[si].fields[fi].imageDescriptions = imageDescriptions
                    inspection.sections[si].fields[fi].imageMeasurementsMM = imageMeasurementsMM
                    inspection.sections[si].fields[fi].photoURL = imageURLs.first
                    break
                }
            }
            try await self.updateInspection(inspection)
        }
        pendingFieldWrite = newTask
        try await newTask.value
    }

    /// Partial Firestore update — only the `status` field. Safe to call concurrently with `updateFieldImageURLs`.
    func updateInspectionStatus(inspectionId: String, status: InspectionStatus) async throws {
        do {
            try await firestoreService.updateInspectionStatus(id: inspectionId, status: status)
        } catch {
            logger.error("Firestore status update failed: \(error.localizedDescription)")
            logger.record(error)
            throw InspectionStorageError.writeFailed
        }
        await MainActor.run {
            if let index = cache.firstIndex(where: { $0.id == inspectionId }) {
                cache[index].status = status
            }
        }
        NotificationCenter.default.post(name: .inspectionDidUpdate, object: nil)
        logger.log("Inspection \(inspectionId) status updated to \(status.rawValue)")
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
            logger.record(error)
            throw InspectionStorageError.deleteFailed
        }

        // 3. Remove from cache + notify other tabs (blocking)
        await MainActor.run { cache.removeAll { $0.id == id } }
        NotificationCenter.default.post(name: .inspectionDidUpdate, object: nil)

        // 4. Evict durable image cache + pending upload set
        Task.detached(priority: .background) {
            await InspectionImageCacheActor.shared.evictInspection(id)
            PendingUploadStore.shared.clearInspection(id)
        }

        // 5. Fire & forget: delete photos + error items + delivery queue tasks
        let storageService = self.storageService
        let firestoreService = self.firestoreService
        let deliveryQueueService = self.deliveryQueueService
        let logger = self.logger
        Task {
            // Delete the entire inspections/{id}/ folder from Firebase Storage.
            // Using listAll() instead of iterating known URLs so orphaned files —
            // whose URLs were lost due to the previous concurrent-upload race condition —
            // are also removed.
            await storageService.deleteFolder(path: "inspections/\(id)")
            logger.log("Storage folder deleted for inspection \(id)")

            // Fetch + delete errorItems subcollection (Firestore + Storage + disk)
            do {
                let errorItems = try await firestoreService.fetchErrorItemsForDeletion(inspectionId: id)
                for item in errorItems {
                    for url in item.imageURLs {
                        do {
                            try await storageService.deleteImage(fromURL: url)
                        } catch {
                            logger.error("Storage delete failed for errorItem image \(url): \(error.localizedDescription)")
                        }
                    }
                    do {
                        try await firestoreService.deleteErrorItem(inspectionId: id, errorItemId: item.id)
                    } catch {
                        logger.error("Firestore delete failed for errorItem \(item.id): \(error.localizedDescription)")
                    }
                    await LocalImageStore.shared.clear(for: item.id)
                }
                if !errorItems.isEmpty {
                    logger.log("Deleted \(errorItems.count) error items for inspection \(id)")
                }
            } catch {
                logger.error("fetchErrorItemsForDeletion failed for inspection \(id): \(error.localizedDescription)")
            }

            do {
                try await deliveryQueueService.deleteTasksForInspection(inspectionId: id)
            } catch {
                logger.error("deleteTasksForInspection failed for inspection \(id): \(error.localizedDescription)")
            }
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
