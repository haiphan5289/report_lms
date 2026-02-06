//
//  FetchInspectionsUseCase.swift
//  report_lms
//
//  Created by GitHub Copilot on 27/1/26.
//

import Foundation

final class FetchInspectionsUseCase {
    private let repository: InspectionRepositoryType

    init(repository: InspectionRepositoryType) {
        self.repository = repository
    }

    func execute() async throws -> [Inspection] {
        try await repository.fetchInspections()
    }
}
