//
//  InspectionServiceType.swift
//  report_lms
//
//  Created by GitHub Copilot on 24/1/26.
//

import Foundation

protocol InspectionServiceType {
    func createInspection(_ model: InspectionModel) async throws -> InspectionModel
    func getInspections() async throws -> [InspectionModel]
    func getInspection(id: String) async throws -> InspectionModel
}