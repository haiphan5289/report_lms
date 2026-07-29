//
//  JoinCompanyViewModel.swift
//  report_lms
//

import Foundation

final class JoinCompanyViewModel: ObservableObject {
    @Published var displayName: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var joinCode: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isSuccess: Bool = false

    private let signUpUseCase: SignUpUseCase
    private let joinCompanyUseCase: JoinCompanyUseCase
    private let rollbackSignUpUseCase: RollbackSignUpUseCase
    private let storageService: InspectionStorageServiceType
    private let userManager: UserManager

    init(
        signUpUseCase: SignUpUseCase,
        joinCompanyUseCase: JoinCompanyUseCase,
        rollbackSignUpUseCase: RollbackSignUpUseCase,
        storageService: InspectionStorageServiceType,
        userManager: UserManager
    ) {
        self.signUpUseCase = signUpUseCase
        self.joinCompanyUseCase = joinCompanyUseCase
        self.rollbackSignUpUseCase = rollbackSignUpUseCase
        self.storageService = storageService
        self.userManager = userManager
    }

    var isFormValid: Bool {
        !displayName.isEmpty && !email.isEmpty && !password.isEmpty && !joinCode.isEmpty
    }

    @MainActor
    func joinCompany() async {
        guard isFormValid else { return }
        isLoading = true
        errorMessage = nil
        do {
            let session = try await signUpUseCase.execute(email: email, password: password)
            do {
                let company = try await joinCompanyUseCase.execute(
                    code: joinCode,
                    userId: session.id,
                    displayName: displayName
                )
                userManager.login(user: session)
                userManager.setCompany(company.id)
                try await storageService.loadCache(companyId: company.id)
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
}
