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

    /// Returns the new company's id.
    func execute(name: String, ownerId: String, ownerDisplayName: String) async throws -> String {
        try await repository.createCompany(name: name, ownerId: ownerId, ownerDisplayName: ownerDisplayName)
    }
}
