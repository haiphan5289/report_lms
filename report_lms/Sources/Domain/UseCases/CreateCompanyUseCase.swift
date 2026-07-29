//
//  CreateCompanyUseCase.swift
//  report_lms
//

import Foundation

final class CreateCompanyUseCase {
    private let repository: CompanyRepositoryType

    init(repository: CompanyRepositoryType) {
        self.repository = repository
    }

    func execute(name: String, ownerId: String, ownerDisplayName: String) async throws -> Company {
        try await repository.createCompany(name: name, ownerId: ownerId, ownerDisplayName: ownerDisplayName)
    }
}
