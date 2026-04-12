//
//  ErrorRepository.swift
//  report_lms
//
//  Created by GitHub Copilot on 12/4/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import Foundation
import UIKit
import OSLog
import FirebaseFirestore
import FirebaseAuth

// MARK: - ErrorRepository

final class ErrorRepository: ErrorRepositoryType {

    private let logger = Logger(subsystem: "com.reportlms", category: "ErrorRepository")

    // MARK: - Private Properties

    private let db = Firestore.firestore()
    private let storageService: FirebaseStorageService

    // MARK: - Initialization

    init(storageService: FirebaseStorageService) {
        self.storageService = storageService
    }

    // MARK: - ErrorRepositoryType

    func fetchErrors(for inspectionId: String) async throws -> [Inspection] {
        let snapshot = try await db
            .collection("inspections")
            .document(inspectionId)
            .collection("errors")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            try? Inspection.fromFirestore(document.data(), id: document.documentID)
        }
    }

    func fetchErrorItems(for inspectionId: String) async throws -> [Inspection] {
        logger.debug("[fetchErrorItems] inspectionId=\(inspectionId, privacy: .public)")
        let snapshot = try await db
            .collection("inspections")
            .document(inspectionId)
            .collection("errorItems")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        let items = snapshot.documents.compactMap { document in
            try? Inspection.fromFirestore(document.data(), id: document.documentID)
        }
        logger.debug("[fetchErrorItems] fetched \(items.count, privacy: .public) items")
        return items
    }

    func saveError(_ inspection: Inspection, for inspectionId: String) async throws {
        let docRef = db
            .collection("inspections")
            .document(inspectionId)
            .collection("errors")
            .document(inspection.id)

        let data = try inspection.toFirestoreData()
        try await docRef.setData(data)
    }

    /// Uploads images to Firebase Storage, then saves the Inspection document
    /// (with `imageURLs`) to the `errorItems` subcollection.
    ///
    /// Storage path: `inspections/{inspectionId}/errors/{inspection.id}/{index}.jpg`
    /// Firestore path: `inspections/{inspectionId}/errorItems/{inspection.id}`
    func saveErrorItem(_ inspection: Inspection, images: [UIImage], for inspectionId: String) async throws {
        // --- Auth state diagnostics ---
        let firebaseUser = Auth.auth().currentUser
        logger.debug("[saveErrorItem] auth uid=\(firebaseUser?.uid ?? "nil", privacy: .public)")
        logger.debug("[saveErrorItem] auth email=\(firebaseUser?.email ?? "nil", privacy: .public)")
        logger.debug("[saveErrorItem] auth isAnonymous=\(firebaseUser?.isAnonymous ?? false, privacy: .public)")
        logger.debug("[saveErrorItem] inspectionId=\(inspectionId, privacy: .public)")
        logger.debug("[saveErrorItem] errorId=\(inspection.id, privacy: .public)")
        logger.debug("[saveErrorItem] imageCount=\(images.count, privacy: .public)")

        // 1. Upload images and collect download URLs
        var imageURLs: [String] = []
        for (index, image) in images.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                logger.warning("[saveErrorItem] Skipping image[\(index, privacy: .public)] — jpegData returned nil")
                continue
            }
            let path = "inspections/\(inspectionId)/errors/\(inspection.id)/\(index).jpg"
            logger.debug("[saveErrorItem] Uploading image[\(index, privacy: .public)] → Storage path: \(path, privacy: .public)")
            do {
                let url = try await storageService.uploadImage(imageData, path: path)
                logger.debug("[saveErrorItem] Upload succeeded[\(index, privacy: .public)] url=\(url, privacy: .public)")
                imageURLs.append(url)
            } catch {
                logger.error("[saveErrorItem] ❌ Storage upload FAILED[\(index, privacy: .public)] path=\(path, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
                throw error
            }
        }

        // 2. Build Firestore document: Inspection fields + imageURLs
        var data = try inspection.toFirestoreData()
        data["imageURLs"] = imageURLs

        // 3. Save to new errorItems subcollection
        let firestorePath = "inspections/\(inspectionId)/errorItems/\(inspection.id)"
        logger.debug("[saveErrorItem] Writing to Firestore: \(firestorePath, privacy: .public)")
        let docRef = db
            .collection("inspections")
            .document(inspectionId)
            .collection("errorItems")
            .document(inspection.id)
        do {
            try await docRef.setData(data)
            logger.debug("[saveErrorItem] ✅ Firestore write succeeded: \(firestorePath, privacy: .public)")
        } catch {
            logger.error("[saveErrorItem] ❌ Firestore write FAILED: \(firestorePath, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}
