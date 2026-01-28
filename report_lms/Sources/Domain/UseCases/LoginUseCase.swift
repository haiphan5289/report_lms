//
//  LoginUseCase.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//

import Foundation

final class LoginUseCase {
    private let repository: AuthRepositoryType
    
    init(repository: AuthRepositoryType) {
        self.repository = repository
    }
    
    func execute(request: LoginRequest) async throws -> UserSession {
        try await repository.login(request: request)
    }
}
