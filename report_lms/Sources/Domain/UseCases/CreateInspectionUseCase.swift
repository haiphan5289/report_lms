//
//  CreateInspectionUseCase.swift
//  report_lms
//
//  Created by GitHub Copilot on 24/1/26.
//

import Foundation

final class CreateInspectionUseCase {
    private let repository: InspectionRepositoryType
    
    init(repository: InspectionRepositoryType) {
        self.repository = repository
    }
    
    func execute(
        productName: String,
        productCode: String,
        orderCode: String,
        inspectionType: String,
        quantity: String,
        factory: String,
        productionUnit: String
    ) async throws -> Inspection {
        let inspection = Inspection(
            productName: productName,
            productCode: productCode,
            orderCode: orderCode,
            inspectionType: inspectionType,
            quantity: quantity,
            factory: factory,
            productionUnit: productionUnit
        )
        return try await repository.createInspection(inspection)
    }
}