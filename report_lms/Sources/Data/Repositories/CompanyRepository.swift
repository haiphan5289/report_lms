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

    func fetchUserProfile(userId: String) async throws -> UserProfile? {
        try await service.fetchUserProfile(userId: userId)
    }

    func createCompany(name: String, ownerId: String, ownerDisplayName: String) async throws -> String {
        try await service.createCompany(name: name, ownerId: ownerId, ownerDisplayName: ownerDisplayName)
    }
}
