//
//  CreateInspectionUseCase.swift
//  report_lms
//
//  Created by GitHub Copilot on 24/1/26.
//

import Foundation

struct InspectionCreationParameters {
    let productName: String
    let productCode: String
    let orderCode: String
    let inspectionType: String
    let quantity: String
    let factory: String
    let productionUnit: String
}

final class CreateInspectionUseCase {
    private let repository: InspectionRepositoryType

    init(repository: InspectionRepositoryType) {
        self.repository = repository
    }

    func execute(parameters: InspectionCreationParameters) async throws -> Inspection {
        let inspection = Inspection(
            productName: parameters.productName,
            productCode: parameters.productCode,
            orderCode: parameters.orderCode,
            inspectionType: parameters.inspectionType,
            quantity: parameters.quantity,
            factory: parameters.factory,
            productionUnit: parameters.productionUnit
        )
        return try await repository.createInspection(inspection)
    }
}
