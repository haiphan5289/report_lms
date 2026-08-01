//
//  LoginViewModel.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//

import Foundation
import LocalAuthentication
import OSLog

final class LoginViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isLoginLoading: Bool = false
    @Published var isBiometricLoading: Bool = false
    @Published var errorMessage: String?
    @Published var userSession: UserSession?
    @Published var isLoginSuccessful: Bool = false
    @Published var isBiometricAvailable: Bool = false
    @Published var biometricType: LABiometryType = .none

    // MARK: - Private Properties
    private let loginUseCase: LoginUseCase
    private let storageService: InspectionStorageServiceType
    private let userManager: UserManager
    private let logger = Logger(subsystem: "com.reportlms.viewmodel", category: "login")

    // MARK: - Initialization
    init(
        loginUseCase: LoginUseCase,
        storageService: InspectionStorageServiceType,
        userManager: UserManager
    ) {
        self.loginUseCase = loginUseCase
        self.storageService = storageService
        self.userManager = userManager
        checkBiometricAvailability()
        loadStoredUsername()
    }

    /// Loads the signed-in user's own inspection cache. Called after every successful
    /// sign-in path (password, biometric). Each inspection belongs to exactly the
    /// inspector (Firebase Auth uid) who created it — no shared/company scope.
    @MainActor
    private func loadInspectionCache(userId: String) async {
        logger.debug("loadInspectionCache: loading for userId=\(userId, privacy: .public)")
        do {
            try await storageService.loadCache(inspectorId: userId)
            logger.debug("loadInspectionCache: inspection cache loaded for userId=\(userId, privacy: .public)")
        } catch {
            logger.error("loadInspectionCache: failed — \(error.localizedDescription, privacy: .public) — logging out")
            errorMessage = "Không thể tải dữ liệu. Vui lòng thử lại."
            userManager.logout()
            isLoginSuccessful = false
        }
    }

    // MARK: - Public Methods

    /// Called once at app launch. `UserManager.init()` sets `isLoggedIn` straight from a
    /// stored Keychain token, without ever loading the inspection cache — so on a relaunch
    /// (as opposed to a fresh sign-in), the cache stays empty for the whole session unless
    /// this runs. No-ops if there's no restored session, or if it was already loaded.
    @MainActor
    func restoreSessionIfNeeded() async {
        guard userManager.isLoggedIn else {
            logger.debug("restoreSessionIfNeeded: skipped — not logged in")
            return
        }
        guard !storageService.isCacheLoaded else {
            logger.debug("restoreSessionIfNeeded: skipped — cache already loaded")
            return
        }
        logger.debug("restoreSessionIfNeeded: restoring session via refreshSession()")
        do {
            let session = try await loginUseCase.refreshSession()
            logger.debug("restoreSessionIfNeeded: refreshSession succeeded, userId=\(session.id, privacy: .public)")
            userSession = session
            userManager.login(user: session)
            await loadInspectionCache(userId: session.id)
        } catch {
            logger.error("restoreSessionIfNeeded: refreshSession failed — \(error.localizedDescription, privacy: .public) — logging out")
            // The underlying Firebase session is gone/expired — fall back to the login screen.
            userManager.logout()
        }
    }

    @MainActor
    func login() async {
        isLoginLoading = true
        errorMessage = nil
        do {
            let request = LoginRequest(username: username, password: password)
            let session = try await loginUseCase.execute(request: request)
            userSession = session
            userManager.login(user: session)
            KeychainManager.saveUsername(username)
            await loadInspectionCache(userId: session.id)
            isLoginSuccessful = userManager.isLoggedIn
        } catch {
            errorMessage = error.localizedDescription
            isLoginSuccessful = false
        }
        isLoginLoading = false
    }

    // MARK: - Biometric Authentication
    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometricType = context.biometryType
        isBiometricAvailable = canEvaluate
    }

    @MainActor
    func biometricLogin() async {
        isBiometricLoading = true
        errorMessage = nil

        let context = LAContext()
        let reason = biometricType == .faceID
            ? "Xác thực bằng Face ID để đăng nhập"
            : "Xác thực bằng Touch ID để đăng nhập"

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            if success {
                await performBiometricLoginWithSession()
            }
        } catch {
            switch error {
            case LAError.userCancel, LAError.userFallback, LAError.systemCancel:
                errorMessage = "Xác thực đã bị hủy"
            case LAError.biometryNotAvailable:
                errorMessage = "Thiết bị không hỗ trợ xác thực sinh trắc học"
            case LAError.biometryNotEnrolled:
                errorMessage = "Chưa thiết lập \(biometricType == .faceID ? "Face ID" : "Touch ID")"
            case LAError.biometryLockout:
                errorMessage = "\(biometricType == .faceID ? "Face ID" : "Touch ID") đã bị khóa tạm thời"
            default:
                errorMessage = "Lỗi xác thực sinh trắc học"
            }
        }
        isBiometricLoading = false
    }

    // Uses the existing Firebase session — no stored password needed.
    @MainActor
    private func performBiometricLoginWithSession() async {
        do {
            let session = try await loginUseCase.refreshSession()
            if let storedUsername = KeychainManager.getStoredUsername() {
                username = storedUsername
            }
            userSession = session
            userManager.login(user: session)
            await loadInspectionCache(userId: session.id)
            isLoginSuccessful = userManager.isLoggedIn
        } catch {
            errorMessage = "Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại."
            isLoginSuccessful = false
        }
    }

    private func loadStoredUsername() {
        if let storedUsername = KeychainManager.getStoredUsername() {
            username = storedUsername
        }
    }

    @MainActor
    func logout() {
        userSession = nil
        userManager.logout()
        isLoginSuccessful = false
        username = ""
        password = ""
        errorMessage = nil
        KeychainManager.deleteCredentials()
    }

    var isLoggedIn: Bool {
        userManager.isLoggedIn
    }
}
