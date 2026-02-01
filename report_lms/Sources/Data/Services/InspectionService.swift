//
//  InspectionService.swift
//  report_lms
//
//  Created by GitHub Copilot on 24/1/26.
//

import Foundation

final class InspectionService: InspectionServiceType {
    
    func createInspection(_ model: InspectionModel) async throws -> InspectionModel {
        // Mock implementation - in real app, this would make API call
        print("🔧 [InspectionService] createInspection() called")
        try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay
        
        // Store in global InspectionStore
        await InspectionStore.shared.addInspection(model)
        print("🔧 [InspectionService] Stored inspection in global store")
        
        return model
    }
    
    func getInspections() async throws -> [InspectionModel] {
        // Fetch from global InspectionStore
        let inspections = await InspectionStore.shared.getAllInspections()
        print("🔧 [InspectionService] getInspections() called, returning \(inspections.count) inspections from global store")
        return inspections
    }
    
    func getInspection(id: String) async throws -> InspectionModel {
        // Fetch from global InspectionStore
        if let inspection = await InspectionStore.shared.getInspection(id: id) {
            return inspection
        }
        throw NSError(domain: "InspectionService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Inspection not found"])
    }
}