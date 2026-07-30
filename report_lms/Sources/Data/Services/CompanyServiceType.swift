//
//  CompanyServiceType.swift
//  report_lms
//

import Foundation

protocol CompanyServiceType {
    /// Fetches the `users/{uid}` profile document, or `nil` if the user hasn't
    /// completed company onboarding yet (e.g. a pre-migration account).
    func fetchUserProfile(userId: String) async throws -> UserProfile?

    /// Creates a new `companies/{id}` doc owned solely by `ownerId`, plus the matching
    /// `users/{ownerId}` profile — one account maps to exactly one company, there is no
    /// join-by-code flow. Returns the new company's id.
    func createCompany(name: String, ownerId: String, ownerDisplayName: String) async throws -> String
}
