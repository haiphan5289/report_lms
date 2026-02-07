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
    @Published var productName: String = "Ghế"
    @Published var orderNumber: String = "001"
    @Published var productCode: String = "001"
    @Published var totalQuantity: String = "0"
    @Published var sampleQuantity: String = "0"
    @Published var boxQuantity: String = "Ngẫu nhiên"
    @Published var factoryName: String = "KUKA"
    @Published var inspectionDate: String = "CN, 28 tháng 12, 2025"
    @Published var factoryLocation: String = "Nhà máy gò vấp"
    
    // MARK: - Initialization
    init() {
        // Initialize with default values
    }
}