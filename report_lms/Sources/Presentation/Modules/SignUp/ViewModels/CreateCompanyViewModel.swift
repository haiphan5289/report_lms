//
//  CreateCompanyViewModel.swift
//  report_lms
//

import Foundation

final class CreateCompanyViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var companyName: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isSuccess: Bool = false
    @Published var createdJoinCode: String?

    private var pendingSession: UserSession?

    private let signUpUseCase: SignUpUseCase
    private let createCompanyUseCase: CreateCompanyUseCase
    private let rollbackSignUpUseCase: RollbackSignUpUseCase
    private let storageService: InspectionStorageServiceType
    private let userManager: UserManager

    init(
        signUpUseCase: SignUpUseCase,
        createCompanyUseCase: CreateCompanyUseCase,
        rollbackSignUpUseCase: RollbackSignUpUseCase,
        storageService: InspectionStorageServiceType,
        userManager: UserManager
    ) {
        self.signUpUseCase = signUpUseCase
        self.createCompanyUseCase = createCompanyUseCase
        self.rollbackSignUpUseCase = rollbackSignUpUseCase
        self.storageService = storageService
        self.userManager = userManager
    }

    var isFormValid: Bool {
        !displayName.isEmpty && !email.isEmpty && !password.isEmpty && !companyName.isEmpty
    }

    @MainActor
    func createCompany() async {
        guard isFormValid else { return }
        isLoading = true
        errorMessage = nil
        do {
            let session = try await signUpUseCase.execute(email: email, password: password)
            do {
                let company = try await createCompanyUseCase.execute(
                    name: companyName,
                    ownerId: session.id,
                    ownerDisplayName: displayName
                )
                userManager.setCompany(company.id)
                try await storageService.loadCache(companyId: company.id)
                pendingSession = session
                createdJoinCode = company.joinCode
                isSuccess = true
            } catch {
                // Undo the just-created auth account so the email is free to retry with.
                await rollbackSignUpUseCase.execute()
                throw error
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Logs the user in once they've dismissed the success screen.
    /// Deferred until now — `userManager.login` flips `isLoggedIn`, which makes `RootView` swap its
    /// entire root immediately, tearing down this screen before the join code could be shown.
    @MainActor
    func finishOnboarding() {
        guard let pendingSession else { return }
        userManager.login(user: pendingSession)
    }
}
