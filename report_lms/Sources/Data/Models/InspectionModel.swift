//
//  InspectionModel.swift
//  report_lms
//
//  Created by GitHub Copilot on 24/1/26.
//

import Foundation

struct InspectionModel: Codable {
    let id: String
    let productName: String
    let productCode: String
    let orderCode: String
    let inspectionType: String
    let createdAt: String
    let inspectorId: String?
    
    func toEntity() -> Inspection {
        Inspection(
            id: id,
            productName: productName,
            productCode: productCode,
            orderCode: orderCode,
            inspectionType: inspectionType,
            createdAt: ISO8601DateFormatter().date(from: createdAt) ?? Date(),
            inspectorId: inspectorId
        )
    }
    
    static func fromEntity(_ entity: Inspection) -> InspectionModel {
        InspectionModel(
            id: entity.id,
            productName: entity.productName,
            productCode: entity.productCode,
            orderCode: entity.orderCode,
            inspectionType: entity.inspectionType,
            createdAt: ISO8601DateFormatter().string(from: entity.createdAt),
            inspectorId: entity.inspectorId
        )
    }
}