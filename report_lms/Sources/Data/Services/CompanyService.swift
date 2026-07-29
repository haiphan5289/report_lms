//
//  CompanyService.swift
//  report_lms
//

import Foundation
import FirebaseFirestore

/// Firestore-backed implementation of `CompanyServiceType`.
///
/// Collections used (none existed before company onboarding was added):
/// - `companies/{companyId}` — the `Company` document.
/// - `joinCodes/{code}` — maps a human-shareable join code to a `companyId`.
///   A separate collection (rather than querying `companies` by field) so the
///   code doubles as its own uniqueness check via `document(code)`.
/// - `users/{uid}` — the `UserProfile` document (didn't exist before; login
///   previously relied solely on Firebase Auth's own user record).
final class CompanyService: CompanyServiceType {
    private let firestoreDatabase = Firestore.firestore()

    func createCompany(name: String, ownerId: String, ownerDisplayName: String) async throws -> Company {
        let code = try await generateUniqueJoinCode()
        let companyRef = firestoreDatabase.collection("companies").document()
        let company = Company(id: companyRef.documentID, name: name, joinCode: code, ownerId: ownerId, createdAt: Date())
        let profile = UserProfile(id: ownerId, companyId: company.id, role: .owner, displayName: ownerDisplayName)

        // Single batch: company + joinCode + owner profile are created atomically —
        // either all three land, or none do. Prevents an orphaned company doc with no
        // owner profile if the app is killed or the network drops mid-write.
        let batch = firestoreDatabase.batch()
        batch.setData(try company.toFirestoreData(), forDocument: companyRef)
        batch.setData(["companyId": company.id], forDocument: firestoreDatabase.collection("joinCodes").document(code))
        batch.setData(try profile.toFirestoreData(), forDocument: firestoreDatabase.collection("users").document(ownerId))
        try await batch.commit()

        return company
    }

    func joinCompany(code: String, userId: String, displayName: String) async throws -> Company {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let joinCodeDoc = try await firestoreDatabase.collection("joinCodes").document(normalizedCode).getDocument()
        guard let companyId = joinCodeDoc.data()?["companyId"] as? String else {
            throw CompanyError.invalidJoinCode
        }

        let companyDoc = try await firestoreDatabase.collection("companies").document(companyId).getDocument()
        guard let data = companyDoc.data(), let company = try? Company.fromFirestore(data, id: companyId) else {
            throw CompanyError.companyNotFound
        }

        let profile = UserProfile(id: userId, companyId: companyId, role: .member, displayName: displayName)
        try await firestoreDatabase.collection("users").document(userId).setData(profile.toFirestoreData())

        return company
    }

    func fetchUserProfile(userId: String) async throws -> UserProfile? {
        let doc = try await firestoreDatabase.collection("users").document(userId).getDocument()
        guard let data = doc.data() else { return nil }
        return try UserProfile.fromFirestore(data, id: userId)
    }

    func fetchCompany(id: String) async throws -> Company {
        let doc = try await firestoreDatabase.collection("companies").document(id).getDocument()
        guard let data = doc.data() else { throw CompanyError.companyNotFound }
        return try Company.fromFirestore(data, id: id)
    }

    /// Generates a 6-character code (excludes ambiguous `0/O/1/I`) and confirms it's
    /// unused by checking `joinCodes/{code}` doesn't already exist. Retries a few times
    /// on collision; at this app's signup volume the chance of exhausting all attempts
    /// is negligible.
    private func generateUniqueJoinCode() async throws -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        for _ in 0..<5 {
            let code = String((0..<6).map { _ in alphabet.randomElement()! })
            let existing = try await firestoreDatabase.collection("joinCodes").document(code).getDocument()
            if !existing.exists {
                return code
            }
        }
        throw CompanyError.codeGenerationFailed
    }
}
