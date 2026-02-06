//
//  FirestoreService.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import Foundation
import FirebaseFirestore

final class FirestoreService {
    private let db = Firestore.firestore()
    
    func saveInspection(_ inspection: Inspection) async throws {
        let docRef = db.collection("inspections").document(inspection.id)
        let data = try inspection.toFirestoreData()
        try await docRef.setData(data)
    }
    
    func fetchInspections() async throws -> [Inspection] {
        let snapshot = try await db.collection("inspections").getDocuments()
        return snapshot.documents.compactMap { document in
            try? Inspection.fromFirestore(document.data(), id: document.documentID)
        }
    }
    
    func updateInspection(_ inspection: Inspection) async throws {
        let docRef = db.collection("inspections").document(inspection.id)
        let data = try inspection.toFirestoreData()
        try await docRef.updateData(data)
    }
    
    func deleteInspection(id: String) async throws {
        try await db.collection("inspections").document(id).delete()
    }
}