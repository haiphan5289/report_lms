//
//  FetchUserProfileUseCase.swift
//  report_lms
//

import Foundation

final class FetchUserProfileUseCase {
    private let repository: CompanyRepositoryType

    init(repository: CompanyRepositoryType) {
        self.repository = repository
    }

    func execute(userId: String) async throws -> UserProfile? {
        try await repository.fetchUserProfile(userId: userId)
    }
}
