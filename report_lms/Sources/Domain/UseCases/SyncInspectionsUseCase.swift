//
//  SyncInspectionsUseCase.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import Foundation

final class SyncInspectionsUseCase {
    private let databaseRepository: DatabaseRepositoryType
    
    init(databaseRepository: DatabaseRepositoryType) {
        self.databaseRepository = databaseRepository
    }
    
    func execute() async throws -> [Inspection] {
        try await databaseRepository.fetchInspections()
    }
    
    func saveInspection(_ inspection: Inspection) async throws {
        try await databaseRepository.saveInspection(inspection)
    }
    
    func updateInspection(_ inspection: Inspection) async throws {
        try await databaseRepository.updateInspection(inspection)
    }
    
    func deleteInspection(id: String) async throws {
        try await databaseRepository.deleteInspection(id: id)
    }
}