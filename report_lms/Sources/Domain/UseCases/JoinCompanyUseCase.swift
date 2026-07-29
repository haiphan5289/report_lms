//
//  JoinCompanyUseCase.swift
//  report_lms
//

import Foundation

final class JoinCompanyUseCase {
    private let repository: CompanyRepositoryType

    init(repository: CompanyRepositoryType) {
        self.repository = repository
    }

    func execute(code: String, userId: String, displayName: String) async throws -> Company {
        try await repository.joinCompany(code: code, userId: userId, displayName: displayName)
    }
}
