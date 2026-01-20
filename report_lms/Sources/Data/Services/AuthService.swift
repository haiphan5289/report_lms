//
//  AuthService.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//

import Foundation

final class AuthService: AuthServiceType {
    func login(username: String, password: String) async throws -> LoginResponse {
        // TODO: Replace with real API call
        try await Task.sleep(nanoseconds: 500_000_000) // Simulate network delay
        if username == "user" && password == "password" {
            return LoginResponse(id: "1", username: username, token: "token_123")
        } else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid credentials"])
        }
    }
}
