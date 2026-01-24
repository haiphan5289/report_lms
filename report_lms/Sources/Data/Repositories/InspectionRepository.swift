//
//  InspectionRepository.swift
//  report_lms
//
//  Created by GitHub Copilot on 24/1/26.
//

import Foundation

final class InspectionRepository: InspectionRepositoryType {
    private let service: InspectionServiceType
    
    init(service: InspectionServiceType) {
        self.service = service
    }
    
    func createInspection(_ inspection: Inspection) async throws -> Inspection {
        let model = InspectionModel.fromEntity(inspection)
        let responseModel = try await service.createInspection(model)
        return responseModel.toEntity()
    }
    
    func getInspections() async throws -> [Inspection] {
        let models = try await service.getInspections()
        return models.map { $0.toEntity() }
    }
    
    func getInspection(id: String) async throws -> Inspection {
        let model = try await service.getInspection(id: id)
        return model.toEntity()
    }
}