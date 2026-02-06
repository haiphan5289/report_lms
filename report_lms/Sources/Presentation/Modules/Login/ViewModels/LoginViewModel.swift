//
//  LoginViewModel.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//

import Foundation

final class LoginViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var userSession: UserSession?
    @Published var isLoginSuccessful: Bool = false
    
    // MARK: - Private Properties
    private let loginUseCase: LoginUseCase
    private let userManager: UserManager
    
    // MARK: - Initialization
    init(loginUseCase: LoginUseCase, userManager: UserManager) {
        self.loginUseCase = loginUseCase
        self.userManager = userManager
    }
    
    // MARK: - Public Methods
    func login() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        do {
            let request = LoginRequest(username: username, password: password)
            let session = try await loginUseCase.execute(request: request)
            await MainActor.run {
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
    
    /// Logs out the current user by clearing session data and removing stored token
    func logout() {
        userSession = nil
        userManager.logout()
        isLoginSuccessful = false
        username = ""
        password = ""
        errorMessage = nil
    }
    
    /// Checks if user has a valid stored authentication token
    var isLoggedIn: Bool {
        return userManager.isLoggedIn
    }
}
