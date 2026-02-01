//
//  LoginViewModel.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//

import Foundation

@MainActor
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
    
    // MARK: - Initialization
    init(loginUseCase: LoginUseCase) {
        self.loginUseCase = loginUseCase
    }
    
    // MARK: - Public Methods
    func login() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let request = LoginRequest(username: username, password: password)
            let session = try await loginUseCase.execute(request: request)
            userSession = session
            isLoginSuccessful = true
        } catch {
            errorMessage = error.localizedDescription
            isLoginSuccessful = false
        }
    }
}
