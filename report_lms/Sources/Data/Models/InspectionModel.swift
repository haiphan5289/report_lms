//
//  InspectionModel.swift
//  report_lms
//
//  Created by GitHub Copilot on 24/1/26.
//

import Foundation

struct InspectionModel: Codable {
    let id: String
    let inspectionNumber: String?
    let companyName: String?
    let productName: String
    let productCode: String
    let orderCode: String
    let inspectionType: String
    let quantity: String
    let factory: String
    let productionUnit: String
    let createdAt: String
    let inspectorId: String?
    let status: String?

    func toEntity() -> Inspection {
        Inspection(
            id: id,
            inspectionNumber: inspectionNumber ?? "",
            companyName: companyName ?? "",
            productName: productName,
            productCode: productCode,
            orderCode: orderCode,
            inspectionType: inspectionType,
            quantity: quantity,
            factory: factory,
            productionUnit: productionUnit,
            createdAt: ISO8601DateFormatter().date(from: createdAt) ?? Date(),
            inspectorId: inspectorId,
            status: InspectionStatus(rawValue: status ?? "") ?? .plan
        )
    }

    static func fromEntity(_ entity: Inspection) -> InspectionModel {
        InspectionModel(
            id: entity.id,
            inspectionNumber: entity.inspectionNumber,
            companyName: entity.companyName,
            productName: entity.productName,
            productCode: entity.productCode,
            orderCode: entity.orderCode,
            inspectionType: entity.inspectionType,
            quantity: entity.quantity,
            factory: entity.factory,
            productionUnit: entity.productionUnit,
            createdAt: ISO8601DateFormatter().string(from: entity.createdAt),
            inspectorId: entity.inspectorId,
            status: entity.status.rawValue
        )
    }
}

// MARK: - ListItemProtocol
extension InspectionModel: ListItemProtocol {
    var title: String? {
        productName
    }

    var datas: [ListDataItem] {
        [
            ListDataItem(id: 1, name: "Mã sản phẩm: \(productCode)"),
            ListDataItem(id: 2, name: "Mã đơn hàng: \(orderCode)"),
            ListDataItem(id: 3, name: "Loại kiểm tra: \(inspectionType)"),
            ListDataItem(id: 4, name: "Số lượng: \(quantity)"),
            ListDataItem(id: 5, name: "Nhà máy: \(factory)"),
            ListDataItem(id: 6, name: "Đơn vị sản xuất: \(productionUnit)")
        ]
    }
}
