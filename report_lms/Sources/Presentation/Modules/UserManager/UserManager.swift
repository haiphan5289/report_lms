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
    /// Set once the user's `UserProfile` has been fetched from Firestore (post-login or app relaunch).
    /// `nil` while the profile fetch is pending — callers that need company-scoped data must wait for this.
    @Published var companyId: String?

    private let logger = Logger(subsystem: "com.reportlms.viewmodel", category: "userManager")

    init() {
        // Check for existing token on app launch
        if KeychainManager.hasAuthToken() {
            isLoggedIn = true
            logger.debug("init: restored isLoggedIn=true from Keychain token, companyId still nil")
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

    func setCompany(_ companyId: String) {
        logger.debug("setCompany: \(companyId, privacy: .public) (was \(self.companyId ?? "nil", privacy: .public))")
        self.companyId = companyId
    }

    func logout() {
        logger.debug("logout: clearing session (was companyId=\(self.companyId ?? "nil", privacy: .public))")
        currentUser = nil
        isLoggedIn = false
        companyId = nil
        KeychainManager.deleteAuthToken()
        CrashlyticsLogger.clearUser()
    }
}
