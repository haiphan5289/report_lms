//
//  InformationPurchaseViewModel.swift
//  report_lms
//
//  Created by Hai Phan on 2026-02-07.
//  Copyright © 2026 report_lms. All rights reserved.
//

import Foundation

@MainActor
final class InformationPurchaseViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var productName: String = "—"
    @Published var orderNumber: String = "—"
    @Published var productCode: String = "—"
    @Published var totalQuantity: String = "—"
    @Published var productionUnit: String = "—"
    @Published var inspectionType: String = "—"
    @Published var factoryName: String = "—"
    @Published var inspectionDate: String = "—"

    // MARK: - Initialization
    init(inspection: Inspection? = nil) {
        guard let i = inspection else { return }
        productName    = i.productName
        orderNumber    = i.orderCode
        productCode    = i.productCode
        totalQuantity  = i.quantity
        productionUnit = i.productionUnit
        inspectionType = i.inspectionType
        factoryName    = i.factory
        inspectionDate = Self.formatDate(i.createdAt)
    }

    // MARK: - Private Helpers
    private static func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .long
        f.locale = Locale(identifier: "vi_VN")
        return f.string(from: date)
    }
}
