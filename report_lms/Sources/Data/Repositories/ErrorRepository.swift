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

actor ErrorRepository: ErrorRepositoryType {

    private let logger = Logger(subsystem: "com.reportlms", category: "ErrorRepository")

    // MARK: - Private Properties

    private let db = Firestore.firestore()
    private let storageService: FirebaseStorageService

    // MARK: - Initialization

    init(storageService: FirebaseStorageService) {
        self.storageService = storageService
    }

    // MARK: - ErrorRepositoryType

    func fetchErrorItems(for inspectionId: String) async throws -> [SavedErrorItem] {
        logger.debug("[fetchErrorItems] inspectionId=\(inspectionId, privacy: .public)")
        let snapshot = try await db
            .collection("inspections")
            .document(inspectionId)
            .collection("errorItems")
            .order(by: "createdAt", descending: true)
            .getDocuments()

        let items = snapshot.documents.compactMap { doc in
            savedErrorItem(from: doc.data(), id: doc.documentID)
        }
        logger.debug("[fetchErrorItems] fetched \(items.count, privacy: .public) items")
        return items
    }

    func saveError(_ item: SavedErrorItem, for inspectionId: String) async throws {
        let docRef = db
            .collection("inspections")
            .document(inspectionId)
            .collection("errors")
            .document(item.id)
        try await docRef.setData(item.toFirestoreData())
    }

    /// Uploads local images to Firebase Storage, merges with existing remote URLs,
    /// then saves the SavedErrorItem to the `errorItems` subcollection.
    ///
    /// Storage path: `inspections/{inspectionId}/errors/{item.id}/{index}.jpg`
    /// Firestore path: `inspections/{inspectionId}/errorItems/{item.id}`
    func saveErrorItem(_ item: SavedErrorItem, imageSources: [ImageSource], for inspectionId: String) async throws -> SavedErrorItem {
        let firebaseUser = Auth.auth().currentUser
        logger.debug("[saveErrorItem] auth uid=\(firebaseUser?.uid ?? "nil", privacy: .public)")
        logger.debug("[saveErrorItem] inspectionId=\(inspectionId, privacy: .public)")
        logger.debug("[saveErrorItem] errorId=\(item.id, privacy: .public)")

        var imageURLs: [String] = []

        // Keep existing remote URLs in order
        for source in imageSources {
            if case .remote(let url) = source {
                imageURLs.append(url)
            }
        }

        // Upload local images
        let localImages = imageSources.compactMap { source -> UIImage? in
            if case .local(let image) = source { return image } else { return nil }
        }
        logger.debug("[saveErrorItem] localImageCount=\(localImages.count, privacy: .public)")

        for (index, image) in localImages.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                logger.warning("[saveErrorItem] Skipping image[\(index, privacy: .public)] — jpegData returned nil")
                continue
            }
            let path = "inspections/\(inspectionId)/errors/\(item.id)/\(index).jpg"
            logger.debug("[saveErrorItem] Uploading image[\(index, privacy: .public)] → \(path, privacy: .public)")
            do {
                let url = try await storageService.uploadImage(imageData, path: path)
                logger.debug("[saveErrorItem] Upload succeeded[\(index, privacy: .public)] url=\(url, privacy: .public)")
                imageURLs.append(url)
            } catch {
                logger.error("[saveErrorItem] ❌ Upload FAILED[\(index, privacy: .public)] error=\(error.localizedDescription, privacy: .public)")
                throw error
            }
        }

        let savedItem = SavedErrorItem(
            id: item.id,
            imageURLs: imageURLs,
            imageNotes: item.imageNotes,
            severity: item.severity,
            generalCondition: item.generalCondition,
            defectType: item.defectType,
            comments: item.comments,
            createdAt: item.createdAt
        )

        let firestorePath = "inspections/\(inspectionId)/errorItems/\(item.id)"
        logger.debug("[saveErrorItem] Writing to Firestore: \(firestorePath, privacy: .public)")
        let docRef = db
            .collection("inspections")
            .document(inspectionId)
            .collection("errorItems")
            .document(item.id)
        do {
            try await docRef.setData(savedItem.toFirestoreData())
            logger.debug("[saveErrorItem] ✅ Firestore write succeeded: \(firestorePath, privacy: .public)")
        } catch {
            logger.error("[saveErrorItem] ❌ Firestore write FAILED: \(firestorePath, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            throw error
        }

        return savedItem
    }

    func deleteErrorItem(_ item: SavedErrorItem, for inspectionId: String) async throws {
        logger.debug("[deleteErrorItem] START id=\(item.id, privacy: .public) imageCount=\(item.imageURLs.count, privacy: .public)")

        for url in item.imageURLs {
            do {
                try await storageService.deleteImage(fromURL: url)
                logger.debug("[deleteErrorItem] Deleted storage image: \(url, privacy: .public)")
            } catch {
                logger.warning("[deleteErrorItem] Failed to delete image (continuing): \(error.localizedDescription, privacy: .public)")
            }
        }

        let docRef = db
            .collection("inspections")
            .document(inspectionId)
            .collection("errorItems")
            .document(item.id)
        try await docRef.delete()
        logger.debug("[deleteErrorItem] ✅ Firestore doc deleted: \(item.id, privacy: .public)")
    }

    // MARK: - Private Helpers

    private func savedErrorItem(from data: [String: Any], id: String) -> SavedErrorItem? {
        guard let severityRaw = data["severity"] as? String,
              let severity = SeverityLevel(rawValue: severityRaw) else { return nil }

        let imageURLs = data["imageURLs"] as? [String] ?? []
        let imageNotes = data["imageNotes"] as? [String] ?? []
        let comments = data["comments"] as? String ?? ""
        let generalCondition = data["generalCondition"] as? Int
        let defectType = (data["defectType"] as? String).flatMap(DefectType.init(rawValue:))

        let createdAt: Date
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        } else if let dateStr = data["createdAt"] as? String {
            createdAt = ISO8601DateFormatter().date(from: dateStr) ?? Date()
        } else {
            createdAt = Date()
        }

        return SavedErrorItem(
            id: id,
            imageURLs: imageURLs,
            imageNotes: imageNotes,
            severity: severity,
            generalCondition: generalCondition,
            defectType: defectType,
            comments: comments,
            createdAt: createdAt
        )
    }
}
