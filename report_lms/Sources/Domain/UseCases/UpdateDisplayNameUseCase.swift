//
//  UpdateDisplayNameUseCase.swift
//  report_lms
//

import Foundation

final class UpdateDisplayNameUseCase {
    private let repository: AuthRepositoryType

    init(repository: AuthRepositoryType) {
        self.repository = repository
    }

    func execute(name: String) async throws {
        try await repository.updateDisplayName(name)
    }

    func currentDisplayName() -> String? {
        repository.currentDisplayName()
    }
}
