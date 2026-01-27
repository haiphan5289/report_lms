//
//  InspectionRepository.swift
//  report_lms
//
//  Created by GitHub Copilot on 24/1/26.
//

import Foundation
import Combine

final class InspectionRepository: InspectionRepositoryType {
    private let service: InspectionServiceType
    private let inspectionsSubject = CurrentValueSubject<[Inspection], Never>([])
    
    var inspectionsPublisher: AnyPublisher<[Inspection], Never> {
        inspectionsSubject.eraseToAnyPublisher()
    }
    
    init(service: InspectionServiceType) {
        self.service = service
    }
    
    func createInspection(_ inspection: Inspection) async throws -> Inspection {
        let model = InspectionModel.fromEntity(inspection)
        let responseModel = try await service.createInspection(model)
        let newInspection = responseModel.toEntity()
        
        // Notify subscribers
        var currentInspections = inspectionsSubject.value
        currentInspections.insert(newInspection, at: 0)
        inspectionsSubject.send(currentInspections)
        
        return newInspection
    }
    
    func getInspections() async throws -> [Inspection] {
        let models = try await service.getInspections()
        return models.map { $0.toEntity() }
    }
    
    func getInspection(id: String) async throws -> Inspection {
        let model = try await service.getInspection(id: id)
        return model.toEntity()
    }
    
    func fetchInspections() async throws -> [Inspection] {
        let models = try await service.getInspections()
        let inspections = models.map { $0.toEntity() }
        inspectionsSubject.send(inspections)
        return inspections
    }
}