//
//  CompanyRepositoryType.swift
//  report_lms
//

import Foundation

protocol CompanyRepositoryType {
    func fetchUserProfile(userId: String) async throws -> UserProfile?
    func createCompany(name: String, ownerId: String, ownerDisplayName: String) async throws -> String
}
