//
//  ForgotPasswordViewModel.swift
//  report_lms
//

import Foundation
import FirebaseAuth

final class ForgotPasswordViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var email: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isSuccess: Bool = false

    // MARK: - Private Properties
    private let forgotPasswordUseCase: ForgotPasswordUseCase

    // MARK: - Initialization
    init(forgotPasswordUseCase: ForgotPasswordUseCase) {
        self.forgotPasswordUseCase = forgotPasswordUseCase
    }

    // MARK: - Public Methods
    @MainActor
    func sendResetLink() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidEmail(trimmedEmail) else {
            errorMessage = "Email không hợp lệ"
            isSuccess = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await forgotPasswordUseCase.execute(email: trimmedEmail)
            isSuccess = true
        } catch {
            // Firebase distinguishes "no account for this email" from a real network
            // failure. Surfacing the former lets an attacker enumerate registered
            // emails, so only network errors are shown — everything else (including
            // "user not found") still resolves to the generic success state.
            let nsError = error as NSError
            if nsError.domain == AuthErrorDomain, AuthErrorCode(rawValue: nsError.code) == .networkError {
                errorMessage = "Lỗi kết nối mạng. Vui lòng thử lại."
                isSuccess = false
            } else {
                isSuccess = true
            }
        }

        isLoading = false
    }

    func reset() {
        email = ""
        errorMessage = nil
        isSuccess = false
        isLoading = false
    }

    // MARK: - Validation
    private static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
}
