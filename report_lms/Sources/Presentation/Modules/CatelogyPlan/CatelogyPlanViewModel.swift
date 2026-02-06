//
//  CatelogyPlanViewModel.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 22/1/26.
//

import Foundation
import SwiftUI

@MainActor
final class CatelogyPlanViewModel: ObservableObject {

    enum InspectionOption: CaseIterable {
        case combine
        case scanBarcode
        case startInspection
        case quickInspection

        var title: String {
            switch self {
            case .combine:
                return "KẾT HỢP CÁC KIỂM TRA"
            case .scanBarcode:
                return "QUÉT MÃ VẠCH ĐỂ TÌM KIỂM TRA"
            case .startInspection:
                return "BẮT ĐẦU KIỂM HÀNG"
            case .quickInspection:
                return "KIỂM HÀNG NHANH"
            }
        }

        var icon: String {
            switch self {
            case .combine:
                return "arrow.right"
            case .scanBarcode:
                return "barcode.viewfinder"
            case .startInspection:
                return "magnifyingglass"
            case .quickInspection:
                return "plus"
            }
        }
    }

    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    var items = InspectionOption.allCases

    // MARK: - Initialization
    init() {
        // Initialize with dependencies if needed
    }

    // MARK: - Public Methods
    func handleCombineInspection() {
        // Placeholder: Implement combine inspection logic
        print("Combine inspection tapped")
    }

    func handleScanBarcode() {
        // Placeholder: Implement scan barcode logic
        print("Scan barcode tapped")
    }

    func handleStartInspection() {
        // Placeholder: Implement start inspection logic
        print("Start inspection tapped")
    }

    func handleQuickInspection() {
        // Placeholder: Implement quick inspection logic
        print("Quick inspection tapped")
    }
}
