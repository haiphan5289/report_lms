//
//  ProfileViewModel.swift
//  report_lms
//

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

    // MARK: - Private Properties
    private let updateDisplayNameUseCase: UpdateDisplayNameUseCase
    private let logger = Logger(subsystem: "com.reportlms.viewmodel", category: "profile")

    // MARK: - Initialization
    init(updateDisplayNameUseCase: UpdateDisplayNameUseCase? = nil) {
        if let useCase = updateDisplayNameUseCase {
            self.updateDisplayNameUseCase = useCase
        } else {
            guard let resolved = Container.shared.resolve(UpdateDisplayNameUseCase.self) else {
                fatalError("UpdateDisplayNameUseCase must be registered in DI container")
            }
            self.updateDisplayNameUseCase = resolved
        }
        loadCurrentDisplayName()
    }

    // MARK: - Public Methods

    func loadCurrentDisplayName() {
        displayName = updateDisplayNameUseCase.currentDisplayName() ?? ""
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
