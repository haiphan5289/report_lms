//
//  AuthServiceType.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//

import Foundation

protocol AuthServiceType {
    func login(username: String, password: String) async throws -> LoginResponse
}
