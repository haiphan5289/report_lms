//
//  UserManager.swift
//  report_lms
//
//  Created by GitHub Copilot on 6/2/26.
//

import Foundation
import OSLog

final class UserManager: ObservableObject {
    @Published var currentUser: UserSession?
    @Published var isLoggedIn: Bool = false

    private let logger = Logger(subsystem: "com.reportlms.viewmodel", category: "userManager")

    init() {
        // Check for existing token on app launch
        if KeychainManager.hasAuthToken() {
            isLoggedIn = true
            logger.debug("init: restored isLoggedIn=true from Keychain token")
            // Note: currentUser remains nil until user explicitly logs in again
            // This is acceptable since RootView only checks isLoggedIn
        } else {
            logger.debug("init: no Keychain token found, isLoggedIn=false")
        }
    }

    func login(user: UserSession) {
        currentUser = user
        isLoggedIn = true
        KeychainManager.saveAuthToken(user.token)
        CrashlyticsLogger.setUserID(user.id)
        CrashlyticsLogger.setKey("username", value: user.username)
        logger.debug("login: userId=\(user.id, privacy: .public)")
    }

    func logout() {
        logger.debug("logout: clearing session")
        currentUser = nil
        isLoggedIn = false
        KeychainManager.deleteAuthToken()
        CrashlyticsLogger.clearUser()
    }
}
