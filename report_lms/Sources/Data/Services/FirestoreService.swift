//
//  FirestoreService.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import Foundation
import FirebaseFirestore

final class FirestoreService {
    private let firestoreDatabase = Firestore.firestore()

    func saveInspection(_ inspection: Inspection) async throws {
        let docRef = firestoreDatabase.collection("inspections").document(inspection.id)
        let data = try inspection.toFirestoreData()
        try await docRef.setData(data)
    }

    /// Fetches inspections belonging to `companyId` only — never the full collection,
    /// so one company can never see another company's inspection data.
    func fetchInspections(companyId: String, limit: Int = 50) async throws -> [Inspection] {
        let snapshot = try await firestoreDatabase
            .collection("inspections")
            .whereField("companyId", isEqualTo: companyId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { document in
            try? Inspection.fromFirestore(document.data(), id: document.documentID)
        }
    }

    func updateInspection(_ inspection: Inspection) async throws {
        let docRef = firestoreDatabase.collection("inspections").document(inspection.id)
        let data = try inspection.toFirestoreData()
        try await docRef.updateData(data)
    }

    /// Partial update — only writes the `status` field; does not touch imageURLs or other fields.
    func updateInspectionStatus(id: String, status: InspectionStatus) async throws {
        try await firestoreDatabase
            .collection("inspections")
            .document(id)
            .updateData(["status": status.rawValue])
    }

    func deleteInspection(id: String) async throws {
        try await firestoreDatabase.collection("inspections").document(id).delete()
    }

    /// Fetches error item IDs + image URLs from the `errorItems` subcollection.
    /// Used during cascade delete to clean up Storage and LocalImageStore.
    func fetchErrorItemsForDeletion(inspectionId: String) async throws -> [(id: String, imageURLs: [String])] {
        let snapshot = try await firestoreDatabase
            .collection("inspections")
            .document(inspectionId)
            .collection("errorItems")
            .getDocuments()
        return snapshot.documents.map { doc in
            let urls = doc.data()["imageURLs"] as? [String] ?? []
            return (id: doc.documentID, imageURLs: urls)
        }
    }

    func deleteErrorItem(inspectionId: String, errorItemId: String) async throws {
        try await firestoreDatabase
            .collection("inspections")
            .document(inspectionId)
            .collection("errorItems")
            .document(errorItemId)
            .delete()
    }
}
