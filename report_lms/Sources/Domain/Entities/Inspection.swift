//
//  Inspection.swift
//  report_lms
//
//  Created by GitHub Copilot on 24/1/26.
//

import Foundation

struct Inspection: Identifiable, Equatable {
    let id: String
    let productName: String
    let productCode: String
    let orderCode: String
    let inspectionType: String
    let createdAt: Date
    let inspectorId: String?
    
    init(
        id: String = UUID().uuidString,
        productName: String,
        productCode: String,
        orderCode: String,
        inspectionType: String,
        createdAt: Date = Date(),
        inspectorId: String? = nil
    ) {
        self.id = id
        self.productName = productName
        self.productCode = productCode
        self.orderCode = orderCode
        self.inspectionType = inspectionType
        self.createdAt = createdAt
        self.inspectorId = inspectorId
    }
}