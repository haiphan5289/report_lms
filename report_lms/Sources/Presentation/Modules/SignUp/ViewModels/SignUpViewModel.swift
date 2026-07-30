//
//  SignUpViewModel.swift
//  report_lms
//

import Foundation

/// Creates a personal Firebase Auth account and its own dedicated company in one step —
/// one account maps to exactly one company, there is no join-by-code flow. On success the
/// account is logged in immediately (`UserManager.isLoggedIn` flips true), which is what
/// causes `RootView` to swap straight to the home screen — no explicit navigation needed.
final class SignUpViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let signUpUseCase: SignUpUseCase
    private let updateDisplayNameUseCase: UpdateDisplayNameUseCase
    private let createCompanyUseCase: CreateCompanyUseCase
    private let rollbackSignUpUseCase: RollbackSignUpUseCase
    private let storageService: InspectionStorageServiceType
    private let userManager: UserManager

    init(
        signUpUseCase: SignUpUseCase,
        updateDisplayNameUseCase: UpdateDisplayNameUseCase,
        createCompanyUseCase: CreateCompanyUseCase,
        rollbackSignUpUseCase: RollbackSignUpUseCase,
        storageService: InspectionStorageServiceType,
        userManager: UserManager
    ) {
        self.signUpUseCase = signUpUseCase
        self.updateDisplayNameUseCase = updateDisplayNameUseCase
        self.createCompanyUseCase = createCompanyUseCase
        self.rollbackSignUpUseCase = rollbackSignUpUseCase
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

            let companyId: String
            do {
                companyId = try await createCompanyUseCase.execute(
                    name: displayName,
                    ownerId: session.id,
                    ownerDisplayName: displayName
                )
            } catch {
                // Company creation failed after the auth account was created — roll the
                // account back so the email is free to retry instead of stuck forever.
                await rollbackSignUpUseCase.execute()
                throw error
            }

            userManager.login(user: session)
            userManager.setCompany(companyId)
            try? await storageService.loadCache(companyId: companyId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
