//
//  CompanyRepository.swift
//  report_lms
//

import Foundation

final class CompanyRepository: CompanyRepositoryType {
    private let service: CompanyServiceType

    init(service: CompanyServiceType) {
        self.service = service
    }

    func createCompany(name: String, ownerId: String, ownerDisplayName: String) async throws -> Company {
        try await service.createCompany(name: name, ownerId: ownerId, ownerDisplayName: ownerDisplayName)
    }

    func joinCompany(code: String, userId: String, displayName: String) async throws -> Company {
        try await service.joinCompany(code: code, userId: userId, displayName: displayName)
    }

    func fetchUserProfile(userId: String) async throws -> UserProfile? {
        try await service.fetchUserProfile(userId: userId)
    }

    func fetchCompany(id: String) async throws -> Company {
        try await service.fetchCompany(id: id)
    }
}
