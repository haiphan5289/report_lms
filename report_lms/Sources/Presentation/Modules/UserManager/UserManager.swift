//
//  UserManager.swift
//  report_lms
//
//  Created by GitHub Copilot on 6/2/26.
//

import Foundation

final class UserManager: ObservableObject {
    @Published var currentUser: UserSession?
    @Published var isLoggedIn: Bool = false

    init() {
        // Check for existing token on app launch
        if KeychainManager.hasAuthToken() {
            isLoggedIn = true
            // Note: currentUser remains nil until user explicitly logs in again
            // This is acceptable since RootView only checks isLoggedIn
        }
    }

    func login(user: UserSession) {
        currentUser = user
        isLoggedIn = true
        KeychainManager.saveAuthToken(user.token)
        CrashlyticsLogger.setUserID(user.id)
        CrashlyticsLogger.setKey("username", value: user.username)
    }

    func logout() {
        currentUser = nil
        isLoggedIn = false
        KeychainManager.deleteAuthToken()
        CrashlyticsLogger.clearUser()
    }
}
