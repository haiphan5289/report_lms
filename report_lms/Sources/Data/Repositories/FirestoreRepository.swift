//
//  FirestoreRepository.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import Foundation

final class FirestoreRepository: DatabaseRepositoryType {
    private let service: FirestoreService
    
    init(service: FirestoreService) {
        self.service = service
    }
    
    func saveInspection(_ inspection: Inspection) async throws {
        try await service.saveInspection(inspection)
    }
    
    func fetchInspections() async throws -> [Inspection] {
        try await service.fetchInspections()
    }
    
    func updateInspection(_ inspection: Inspection) async throws {
        try await service.updateInspection(inspection)
    }
    
    func deleteInspection(id: String) async throws {
        try await service.deleteInspection(id: id)
    }
}