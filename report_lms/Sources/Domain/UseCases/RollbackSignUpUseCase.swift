//
//  RollbackSignUpUseCase.swift
//  report_lms
//

import Foundation

/// Deletes a just-created Firebase Auth account when the follow-up company creation
/// step fails, so sign-up is effectively all-or-nothing: the email is never left
/// "used up" by an account with no company attached.
final class RollbackSignUpUseCase {
    private let repository: AuthRepositoryType

    init(repository: AuthRepositoryType) {
        self.repository = repository
    }

    func execute() async {
        try? await repository.deleteCurrentUser()
    }
}
