//
//  LoginResponse.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//

import Foundation

struct LoginResponse: Codable {
    let id: String
    let username: String
    let token: String

    func toEntity() -> UserSession {
        UserSession(id: id, username: username, token: token)
    }
}
