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
        print("📦 [InspectionRepository] createInspection() called")
        let model = InspectionModel.fromEntity(inspection)
        let responseModel = try await service.createInspection(model)
        let newInspection = responseModel.toEntity()
        print("📦 [InspectionRepository] Inspection created: \(newInspection.id)")

        // Notify subscribers
        var currentInspections = inspectionsSubject.value
        print("📦 [InspectionRepository] Current inspections count: \(currentInspections.count)")
        currentInspections.insert(newInspection, at: 0)
        print("📦 [InspectionRepository] New inspections count: \(currentInspections.count)")
        print("📦 [InspectionRepository] Sending update to inspectionsSubject...")
        inspectionsSubject.send(currentInspections)
        print("📦 [InspectionRepository] Update sent to inspectionsSubject")

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
        print("📦 [InspectionRepository] fetchInspections() called")
        let models = try await service.getInspections()
        let inspections = models.map { $0.toEntity() }
        print("📦 [InspectionRepository] Fetched \(inspections.count) inspections")
        print("📦 [InspectionRepository] Sending to inspectionsSubject...")
        inspectionsSubject.send(inspections)
        print("📦 [InspectionRepository] Sent to inspectionsSubject")
        return inspections
    }
}
