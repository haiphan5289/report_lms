//
//  CompanyRepositoryType.swift
//  report_lms
//

import Foundation

protocol CompanyRepositoryType {
    func createCompany(name: String, ownerId: String, ownerDisplayName: String) async throws -> Company
    func joinCompany(code: String, userId: String, displayName: String) async throws -> Company
    func fetchUserProfile(userId: String) async throws -> UserProfile?
    func fetchCompany(id: String) async throws -> Company
}
