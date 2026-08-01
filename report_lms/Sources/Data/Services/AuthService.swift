//
//  AuthService.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//

import Foundation
import FirebaseAuth

final class AuthService: AuthServiceType {
    func login(username: String, password: String) async throws -> LoginResponse {
        do {
            let result = try await Auth.auth().signIn(withEmail: username, password: password)
            return LoginResponse(
                id: result.user.uid,
                username: result.user.email ?? username,
                token: try await result.user.getIDToken()
            )
        } catch {
            throw NSError(
                domain: "FirebaseAuth",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Invalid credentials"]
            )
        }
    }

    func signUp(email: String, password: String) async throws -> LoginResponse {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            return LoginResponse(
                id: result.user.uid,
                username: result.user.email ?? email,
                token: try await result.user.getIDToken()
            )
        } catch let error as NSError {
            let message: String
            switch AuthErrorCode(rawValue: error.code) {
            case .emailAlreadyInUse:
                message = "Email này đã được đăng ký"
            case .weakPassword:
                message = "Mật khẩu quá yếu, vui lòng chọn mật khẩu khác"
            case .invalidEmail:
                message = "Email không hợp lệ"
            default:
                message = "Không thể tạo tài khoản, vui lòng thử lại"
            }
            throw NSError(domain: "FirebaseAuth", code: error.code, userInfo: [NSLocalizedDescriptionKey: message])
        }
    }

    func refreshSession() async throws -> UserSession {
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "FirebaseAuth",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "No active session. Please log in again."]
            )
        }
        let token = try await user.getIDToken(forcingRefresh: true)
        return UserSession(id: user.uid, username: user.email ?? "", token: token)
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func updateDisplayName(_ name: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(
                domain: "FirebaseAuth",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "No active session. Please log in again."]
            )
        }
        let changeRequest = user.createProfileChangeRequest()
        changeRequest.displayName = name
        try await changeRequest.commitChanges()
    }

    func currentDisplayName() -> String? {
        Auth.auth().currentUser?.displayName
    }
}
