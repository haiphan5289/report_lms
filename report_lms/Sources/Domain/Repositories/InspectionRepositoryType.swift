//
//  InspectionRepositoryType.swift
//  report_lms
//
//  Created by GitHub Copilot on 24/1/26.
//

import Foundation

protocol InspectionRepositoryType {
    func createInspection(_ inspection: Inspection) async throws -> Inspection
    func getInspections() async throws -> [Inspection]
    func getInspection(id: String) async throws -> Inspection
}