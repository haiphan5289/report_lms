//
//  Inspection.swift
//  report_lms
//
//  Created by GitHub Copilot on 24/1/26.
//

import Foundation

struct Inspection: Identifiable, Equatable, Hashable {
    let id: String
    let inspectionNumber: String
    let companyName: String
    let productName: String
    let productCode: String
    let orderCode: String
    let inspectionType: String
    let quantity: String
    let factory: String
    let productionUnit: String
    let createdAt: Date
    let inspectorId: String?
    let status: InspectionStatus
    
    init(
        id: String = UUID().uuidString,
        inspectionNumber: String = "",
        companyName: String = "",
        productName: String,
        productCode: String,
        orderCode: String,
        inspectionType: String,
        quantity: String,
        factory: String,
        productionUnit: String,
        createdAt: Date = Date(),
        inspectorId: String? = nil,
        status: InspectionStatus = .plan
    ) {
        self.id = id
        self.inspectionNumber = inspectionNumber
        self.companyName = companyName
        self.productName = productName
        self.productCode = productCode
        self.orderCode = orderCode
        self.inspectionType = inspectionType
        self.quantity = quantity
        self.factory = factory
        self.productionUnit = productionUnit
        self.createdAt = createdAt
        self.inspectorId = inspectorId
        self.status = status
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "EEE, dd MMM yyyy"
        return formatter.string(from: createdAt)
    }
}