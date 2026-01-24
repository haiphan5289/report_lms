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
        try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network delay
        return model
    }
    
    func getInspections() async throws -> [InspectionModel] {
        // Mock implementation
        []
    }
    
    func getInspection(id: String) async throws -> InspectionModel {
        // Mock implementation
        throw NSError(domain: "InspectionService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Inspection not found"])
    }
}