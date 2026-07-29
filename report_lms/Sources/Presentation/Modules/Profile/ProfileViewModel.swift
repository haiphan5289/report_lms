//
//  ProfileViewModel.swift
//  report_lms
//

import Combine
import Foundation
import OSLog

@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Constants
    static let displayNameMaxLength = 50

    // MARK: - Published Properties
    @Published var displayName: String = ""
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var showSaveSuccess = false
    @Published var companyJoinCode: String?
    @Published var isLoadingCompanyJoinCode = false

    // MARK: - Private Properties
    private let updateDisplayNameUseCase: UpdateDisplayNameUseCase
    private let fetchCompanyUseCase: FetchCompanyUseCase
    private let userManager: UserManager
    private let logger = Logger(subsystem: "com.reportlms.viewmodel", category: "profile")
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(
        updateDisplayNameUseCase: UpdateDisplayNameUseCase? = nil,
        fetchCompanyUseCase: FetchCompanyUseCase? = nil,
        userManager: UserManager? = nil
    ) {
        if let useCase = updateDisplayNameUseCase {
            self.updateDisplayNameUseCase = useCase
        } else {
            guard let resolved = Container.shared.resolve(UpdateDisplayNameUseCase.self) else {
                fatalError("UpdateDisplayNameUseCase must be registered in DI container")
            }
            self.updateDisplayNameUseCase = resolved
        }

        if let useCase = fetchCompanyUseCase {
            self.fetchCompanyUseCase = useCase
        } else {
            guard let resolved = Container.shared.resolve(FetchCompanyUseCase.self) else {
                fatalError("FetchCompanyUseCase must be registered in DI container")
            }
            self.fetchCompanyUseCase = resolved
        }

        if let userManager {
            self.userManager = userManager
        } else {
            guard let resolved = Container.shared.resolve(UserManager.self) else {
                fatalError("UserManager must be registered in DI container")
            }
            self.userManager = resolved
        }

        loadCurrentDisplayName()
        observeCompanyId()
    }

    // MARK: - Public Methods

    func loadCurrentDisplayName() {
        displayName = updateDisplayNameUseCase.currentDisplayName() ?? ""
    }

    /// `userManager.companyId` may still be `nil` at this exact moment — app-launch session
    /// restoration (`LoginViewModel.restoreSessionIfNeeded`) fetches it asynchronously in
    /// parallel with this screen appearing. Rather than checking once and giving up, this
    /// subscribes so the join code loads whenever `companyId` actually becomes available,
    /// including if that happens after this screen is already on screen.
    private func observeCompanyId() {
        userManager.$companyId
            .removeDuplicates()
            .sink { [weak self] companyId in
                guard let self, let companyId, self.companyJoinCode == nil else { return }
                Task { await self.loadCompanyJoinCode(companyId: companyId) }
            }
            .store(in: &cancellables)
    }

    private func loadCompanyJoinCode(companyId: String) async {
        isLoadingCompanyJoinCode = true
        do {
            let company = try await withTimeout(seconds: 10) { [fetchCompanyUseCase] in
                try await fetchCompanyUseCase.execute(companyId: companyId)
            }
            companyJoinCode = company.joinCode
        } catch {
            logger.error("Failed to fetch company join code: \(error.localizedDescription)")
        }
        isLoadingCompanyJoinCode = false
    }

    func save() async {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            errorMessage = LocalizationManager.shared.localize("profile.error.emptyName")
            return
        }

        guard trimmedName.count <= Self.displayNameMaxLength else {
            errorMessage = LocalizationManager.shared.localize("profile.error.maxLength", Self.displayNameMaxLength)
            return
        }

        errorMessage = nil
        isSaving = true

        do {
            try await updateDisplayNameUseCase.execute(name: trimmedName)
            displayName = trimmedName
            showSaveSuccess = true
            logger.log("Display name updated successfully")
        } catch {
            logger.error("Failed to update display name: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
