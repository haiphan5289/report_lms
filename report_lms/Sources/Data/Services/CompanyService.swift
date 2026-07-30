//
//  CompanyService.swift
//  report_lms
//

import Foundation
import FirebaseFirestore

/// Firestore-backed implementation of `CompanyServiceType`.
///
/// Reads `users/{uid}` — the `UserProfile` document, written by an administrator when
/// provisioning an account (one account maps to exactly one company; there is no
/// in-app company creation or join-by-code flow).
final class CompanyService: CompanyServiceType {
    private let firestoreDatabase = Firestore.firestore()

    func fetchUserProfile(userId: String) async throws -> UserProfile? {
        let doc = try await firestoreDatabase.collection("users").document(userId).getDocument()
        guard let data = doc.data() else { return nil }
        return try UserProfile.fromFirestore(data, id: userId)
    }

    func createCompany(name: String, ownerId: String, ownerDisplayName: String) async throws -> String {
        let companyRef = firestoreDatabase.collection("companies").document()
        let companyData: [String: Any] = [
            "id": companyRef.documentID,
            "name": name,
            "ownerId": ownerId,
            "createdAt": ISO8601DateFormatter().string(from: Date()),
        ]
        let profile = UserProfile(id: ownerId, companyId: companyRef.documentID, role: .owner, displayName: ownerDisplayName)

        // Single batch: company + owner profile are created atomically — either both land
        // or neither does, so a mid-write failure never leaves an orphaned company with no
        // owner profile (or vice versa).
        let batch = firestoreDatabase.batch()
        batch.setData(companyData, forDocument: companyRef)
        batch.setData(try profile.toFirestoreData(), forDocument: firestoreDatabase.collection("users").document(ownerId))
        try await batch.commit()

        return companyRef.documentID
    }
}
