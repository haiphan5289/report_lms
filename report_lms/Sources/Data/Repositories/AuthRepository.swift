//
//  AuthRepository.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//

import Foundation

final class AuthRepository: AuthRepositoryType {
    private let service: AuthServiceType

    init(service: AuthServiceType) {
        self.service = service
    }

    func login(request: LoginRequest) async throws -> UserSession {
        let response = try await service.login(username: request.username, password: request.password)
        return response.toEntity()
    }

    func refreshSession() async throws -> UserSession {
        try await service.refreshSession()
    }
}
