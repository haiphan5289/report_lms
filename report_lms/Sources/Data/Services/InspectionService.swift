//
//  InspectionService.swift
//  report_lms
//
//  Created by GitHub Copilot on 24/1/26.
//

import Foundation

final class InspectionService: InspectionServiceType {
    // In-memory storage for mock data
    private var inspections: [InspectionModel] = []
    
    func createInspection(_ model: InspectionModel) async throws -> InspectionModel {
        // Mock implementation - in real app, this would make API call
        print("🔧 [InspectionService] createInspection() called")
        try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay
        
        // Store in memory
        inspections.insert(model, at: 0)
        print("🔧 [InspectionService] Stored inspection, total count: \(inspections.count)")
        
        return model
    }
    
    func getInspections() async throws -> [InspectionModel] {
        // Mock implementation - return stored inspections
        print("🔧 [InspectionService] getInspections() called, returning \(inspections.count) inspections")
        return inspections
    }
    
    func getInspection(id: String) async throws -> InspectionModel {
        // Mock implementation
        if let inspection = inspections.first(where: { $0.id == id }) {
            return inspection
        }
        throw NSError(domain: "InspectionService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Inspection not found"])
    }
}