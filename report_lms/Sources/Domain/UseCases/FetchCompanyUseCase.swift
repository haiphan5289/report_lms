//
//  FetchCompanyUseCase.swift
//  report_lms
//

import Foundation

final class FetchCompanyUseCase {
    private let repository: CompanyRepositoryType

    init(repository: CompanyRepositoryType) {
        self.repository = repository
    }

    func execute(companyId: String) async throws -> Company {
        try await repository.fetchCompany(id: companyId)
    }
}
