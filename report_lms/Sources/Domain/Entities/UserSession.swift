//
//  UserSession.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//

import Foundation

struct UserSession: Equatable, Identifiable {
    let id: String
    let username: String
    let token: String
}
