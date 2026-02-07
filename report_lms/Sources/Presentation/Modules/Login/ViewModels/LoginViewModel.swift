//
//  LoginViewModel.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//

import Foundation
import LocalAuthentication

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
    private let userManager: UserManager

    // MARK: - Initialization
    init(loginUseCase: LoginUseCase, userManager: UserManager) {
        self.loginUseCase = loginUseCase
        self.userManager = userManager
        checkBiometricAvailability()
        loadStoredCredentials()
    }

    // MARK: - Public Methods
    func login() async {
        await MainActor.run {
            isLoginLoading = true
            errorMessage = nil
        }
        defer {
            Task { @MainActor in
                isLoginLoading = false
            }
        }
        do {
            let request = LoginRequest(username: username, password: password)
            let session = try await loginUseCase.execute(request: request)
            await MainActor.run {
                userSession = session
                userManager.login(user: session)
                isLoginSuccessful = true
                storeCredentials() // Store credentials for biometric login
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoginSuccessful = false
            }
        }
    }

    // MARK: - Biometric Authentication
    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?

        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometricType = context.biometryType
        isBiometricAvailable = canEvaluate
    }

    func biometricLogin() async {
        await MainActor.run {
            isBiometricLoading = true
            errorMessage = nil
        }
        defer {
            Task { @MainActor in
                isBiometricLoading = false
            }
        }

        let context = LAContext()
        let reason = biometricType == .faceID ? "Xác thực bằng Face ID để đăng nhập" : "Xác thực bằng Touch ID để đăng nhập"

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            if success {
                // Biometric authentication successful, now login with stored credentials
                await performLoginWithStoredCredentials()
            }
        } catch {
            await MainActor.run {
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
        }
    }

    private func performLoginWithStoredCredentials() async {
        // Retrieve stored credentials
        guard let storedUsername = KeychainManager.getStoredUsername(),
              let storedPassword = KeychainManager.getStoredPassword() else {
            await MainActor.run {
                errorMessage = "Không tìm thấy thông tin đăng nhập đã lưu"
            }
            return
        }

        do {
            let request = LoginRequest(username: storedUsername, password: storedPassword)
            let session = try await loginUseCase.execute(request: request)
            await MainActor.run {
                username = storedUsername
                password = storedPassword
                userSession = session
                userManager.login(user: session)
                isLoginSuccessful = true
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoginSuccessful = false
            }
        }
    }

    private func loadStoredCredentials() {
        if let storedUsername = KeychainManager.getStoredUsername() {
            username = storedUsername
        }
    }

    private func storeCredentials() {
        KeychainManager.saveCredentials(username: username, password: password)
    }

    /// Logs out the current user by clearing session data and removing stored token
    func logout() {
        userSession = nil
        userManager.logout()
        isLoginSuccessful = false
        username = ""
        password = ""
        errorMessage = nil
        // Clear stored credentials from Keychain for security
        KeychainManager.deleteCredentials()
    }

    /// Checks if user has a valid stored authentication token
    var isLoggedIn: Bool {
        return userManager.isLoggedIn
    }
}
