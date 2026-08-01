//
//  SignUpViewModel.swift
//  report_lms
//

import Foundation

/// Creates a personal Firebase Auth account — no organization/company is created or
/// joined. On success the account is logged in immediately (`UserManager.isLoggedIn`
/// flips true), which is what causes `RootView` to swap straight to the home screen —
/// no explicit navigation needed.
final class SignUpViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let signUpUseCase: SignUpUseCase
    private let updateDisplayNameUseCase: UpdateDisplayNameUseCase
    private let storageService: InspectionStorageServiceType
    private let userManager: UserManager

    init(
        signUpUseCase: SignUpUseCase,
        updateDisplayNameUseCase: UpdateDisplayNameUseCase,
        storageService: InspectionStorageServiceType,
        userManager: UserManager
    ) {
        self.signUpUseCase = signUpUseCase
        self.updateDisplayNameUseCase = updateDisplayNameUseCase
        self.storageService = storageService
        self.userManager = userManager
    }

    var isFormValid: Bool {
        !displayName.isEmpty && !email.isEmpty && !password.isEmpty
    }

    @MainActor
    func signUp() async {
        isLoading = true
        errorMessage = nil
        do {
            let session = try await signUpUseCase.execute(email: email, password: password)
            try? await updateDisplayNameUseCase.execute(name: displayName)
            userManager.login(user: session)
            try? await storageService.loadCache(inspectorId: session.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
