//
//  DatabaseRepositoryType.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import Foundation

protocol DatabaseRepositoryType {
    func saveInspection(_ inspection: Inspection) async throws
    func fetchInspections() async throws -> [Inspection]
    func updateInspection(_ inspection: Inspection) async throws
    func deleteInspection(id: String) async throws
}
