//
//  SignUpUseCase.swift
//  report_lms
//

import Foundation

final class SignUpUseCase {
    private let repository: AuthRepositoryType

    init(repository: AuthRepositoryType) {
        self.repository = repository
    }

    func execute(email: String, password: String) async throws -> UserSession {
        try await repository.signUp(email: email, password: password)
    }
}
