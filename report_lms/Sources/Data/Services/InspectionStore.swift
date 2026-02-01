//
//  InspectionStore.swift
//  report_lms
//
//  Created by GitHub Copilot on 1/2/26.
//

import Foundation

/// Global in-memory store for inspections
/// Thread-safe using @MainActor
@MainActor
final class InspectionStore {
    // MARK: - Singleton
    static let shared = InspectionStore()
    
    // MARK: - Properties
    private(set) var inspections: [InspectionModel] = []
    
    // MARK: - Initialization
    private init() {
        loadDefaultMockData()
    }
    
    // MARK: - Public Methods
    
    /// Add new inspection to the store
    func addInspection(_ inspection: InspectionModel) {
        inspections.insert(inspection, at: 0)
        print("✅ [InspectionStore] Added inspection: \(inspection.id), total: \(inspections.count)")
    }
    
    /// Get all inspections from the store
    func getAllInspections() -> [InspectionModel] {
        return inspections
    }
    
    /// Get specific inspection by ID
    func getInspection(id: String) -> InspectionModel? {
        return inspections.first(where: { $0.id == id })
    }
    
    /// Clear all inspections (useful for testing)
    func clearAll() {
        inspections.removeAll()
        print("🗑️ [InspectionStore] Cleared all inspections")
    }
    
    // MARK: - Private Methods
    
    /// Load default mock data for development/demo
    private func loadDefaultMockData() {
        let mockInspections = [
            InspectionModel(
                id: "MOCK-001",
                inspectionNumber: "INS-2026-001",
                companyName: "Công ty TNHH ABC",
                productName: "Áo thun cotton",
                productCode: "AT-001",
                orderCode: "ORD-2026-001",
                inspectionType: "Kiểm tra chất lượng",
                quantity: "1000",
                factory: "Nhà máy Hà Nội",
                productionUnit: "Xưởng sản xuất 1",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                inspectorId: nil,
                status: InspectionStatus.plan.rawValue
            ),
            InspectionModel(
                id: "MOCK-002",
                inspectionNumber: "INS-2026-002",
                companyName: "Công ty TNHH XYZ",
                productName: "Quần jean nam",
                productCode: "QJ-002",
                orderCode: "ORD-2026-002",
                inspectionType: "Kiểm tra cuối cùng",
                quantity: "500",
                factory: "Nhà máy TP.HCM",
                productionUnit: "Xưởng sản xuất 2",
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-86400)),
                inspectorId: nil,
                status: InspectionStatus.plan.rawValue
            ),
            InspectionModel(
                id: "MOCK-003",
                inspectionNumber: "INS-2026-003",
                companyName: "Công ty TNHH DEF",
                productName: "Váy công sở",
                productCode: "VCS-003",
                orderCode: "ORD-2026-003",
                inspectionType: "Kiểm tra trong quá trình",
                quantity: "800",
                factory: "Nhà máy Đà Nẵng",
                productionUnit: "Xưởng sản xuất 3",
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-172800)),
                inspectorId: nil,
                status: InspectionStatus.plan.rawValue
            ),
            InspectionModel(
                id: "MOCK-004",
                inspectionNumber: "INS-2026-004",
                companyName: "Công ty TNHH GHI",
                productName: "Áo khoác nam",
                productCode: "AK-004",
                orderCode: "ORD-2026-004",
                inspectionType: "Kiểm tra chất lượng",
                quantity: "600",
                factory: "Nhà máy Hà Nội",
                productionUnit: "Xưởng sản xuất 1",
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-259200)),
                inspectorId: nil,
                status: InspectionStatus.plan.rawValue
            ),
            InspectionModel(
                id: "MOCK-005",
                inspectionNumber: "INS-2026-005",
                companyName: "Công ty TNHH JKL",
                productName: "Áo sơ mi nữ",
                productCode: "ASM-005",
                orderCode: "ORD-2026-005",
                inspectionType: "Kiểm tra cuối cùng",
                quantity: "1200",
                factory: "Nhà máy Biên Hòa",
                productionUnit: "Xưởng sản xuất 4",
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-604800)),
                inspectorId: nil,
                status: InspectionStatus.plan.rawValue
            ),
            InspectionModel(
                id: "MOCK-006",
                inspectionNumber: "INS-2026-006",
                companyName: "Công ty TNHH MNO",
                productName: "Quần tây nam",
                productCode: "QT-006",
                orderCode: "ORD-2026-006",
                inspectionType: "Kiểm tra chất lượng",
                quantity: "700",
                factory: "Nhà máy Hải Phòng",
                productionUnit: "Xưởng sản xuất 5",
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-691200)),
                inspectorId: nil,
                status: InspectionStatus.plan.rawValue
            )
        ]
        
        inspections = mockInspections
        print("📦 [InspectionStore] Loaded \(inspections.count) default mock inspections")
    }
}
