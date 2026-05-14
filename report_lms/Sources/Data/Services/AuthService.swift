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
}
