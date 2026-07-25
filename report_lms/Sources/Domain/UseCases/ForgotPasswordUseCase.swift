//
//  ForgotPasswordUseCase.swift
//  report_lms
//

import Foundation

final class ForgotPasswordUseCase {
    private let repository: AuthRepositoryType

    init(repository: AuthRepositoryType) {
        self.repository = repository
    }

    func execute(email: String) async throws {
        try await repository.sendPasswordReset(email: email)
    }
}
