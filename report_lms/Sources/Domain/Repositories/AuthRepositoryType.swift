//
//  AuthRepositoryType.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//

import Foundation

protocol AuthRepositoryType {
    func login(request: LoginRequest) async throws -> UserSession
    func signUp(email: String, password: String) async throws -> UserSession
    func deleteCurrentUser() async throws
    func refreshSession() async throws -> UserSession
    func sendPasswordReset(email: String) async throws
    func updateDisplayName(_ name: String) async throws
    func currentDisplayName() -> String?
}
