//
//  Inspection.swift
//  report_lms
//
//  Created by GitHub Copilot on 24/1/26.
//  Updated: March 6, 2026 - Merged with InspectionDetail
//

import Foundation

struct Inspection: Identifiable, Equatable, Hashable, Codable {
    // MARK: - Basic Information (from CreateInspectionView)
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
    var status: InspectionStatus
    
    // MARK: - Inspection Form Data (filled in InspectionDetailView)
    var sections: [InspectionSection]
    var orderQuantity: Int
    var actualCompletedQuantity: Int
    var aqlInspectionQuantity: Int
    var inspectedQuantity: Int
    
    // MARK: - Computed Properties
    var factoryName: String {
        factory
    }

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
        status: InspectionStatus = .plan,
        sections: [InspectionSection] = [],
        orderQuantity: Int = 0,
        actualCompletedQuantity: Int = 0,
        aqlInspectionQuantity: Int = 0,
        inspectedQuantity: Int = 0
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
        self.sections = sections
        self.orderQuantity = orderQuantity
        self.actualCompletedQuantity = actualCompletedQuantity
        self.aqlInspectionQuantity = aqlInspectionQuantity
        self.inspectedQuantity = inspectedQuantity
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "EEE, dd MMM yyyy"
        return formatter.string(from: createdAt)
    }

    func toFirestoreData() throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return dict ?? [:]
    }

    static func fromFirestore(_ data: [String: Any], id: String) throws -> Inspection {
        var mutableData = data
        mutableData["id"] = id

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let jsonData = try JSONSerialization.data(withJSONObject: mutableData)
        return try decoder.decode(Inspection.self, from: jsonData)
    }
}

// MARK: - InspectionSection

struct InspectionSection: Identifiable, Equatable, Hashable, Codable {
    let id: String
    let title: String
    var fields: [InspectionField]
    let order: Int

    var itemCount: Int {
        fields.count
    }
}

// MARK: - InspectionField

struct InspectionField: Identifiable, Equatable, Hashable, Codable {
    let id: String
    let label: String
    let type: FieldType
    var photoURL: String?
    let isRequired: Bool

    enum FieldType: String, Codable {
        case text
        case photo
        case checkbox
        case number
    }
}

// MARK: - Mock Data Extension

extension Inspection {
    /// Returns empty sections template for new inspections
    static func emptyTemplate() -> [InspectionSection] {
        [
            InspectionSection(
                id: "section1",
                title: "Ngoài thùng carton",
                fields: [
                    InspectionField(
                        id: "field1_1",
                        label: "Tổng quan về thùng carton",
                        type: .photo,
                        photoURL: nil,
                        isRequired: true
                    ),
                    InspectionField(
                        id: "field1_2",
                        label: "Thông tin in trên thùng carton",
                        type: .photo,
                        photoURL: nil,
                        isRequired: true
                    )
                ],
                order: 1
            ),
            InspectionSection(
                id: "section2",
                title: "Trong thùng carton",
                fields: [
                    InspectionField(
                        id: "field2_1",
                        label: "Bên trong thùng carton",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field2_2",
                        label: "Cách xếp sản phẩm",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    )
                ],
                order: 2
            ),
            InspectionSection(
                id: "section3",
                title: "Tổng quan về sản phẩm",
                fields: [
                    InspectionField(
                        id: "field3_1",
                        label: "Hình ảnh tổng thể sản phẩm",
                        type: .photo,
                        photoURL: nil,
                        isRequired: true
                    ),
                    InspectionField(
                        id: "field3_2",
                        label: "Kích thước sản phẩm",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field3_3",
                        label: "Màu sắc sản phẩm",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field3_4",
                        label: "Chất liệu sản phẩm",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field3_5",
                        label: "Logo và nhãn mác",
                        type: .photo,
                        photoURL: nil,
                        isRequired: true
                    ),
                    InspectionField(
                        id: "field3_6",
                        label: "Đóng gói sản phẩm",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field3_7",
                        label: "Tem mác và nhãn",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field3_8",
                        label: "Thông tin khác",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    )
                ],
                order: 3
            ),
            InspectionSection(
                id: "section4",
                title: "Vật liệu",
                fields: [
                    InspectionField(
                        id: "field4_1",
                        label: "Chi tiết vật liệu",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    )
                ],
                order: 4
            ),
            InspectionSection(
                id: "section5",
                title: "Hoàn thiện",
                fields: [
                    InspectionField(
                        id: "field5_1",
                        label: "Hoàn thiện sản phẩm",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    )
                ],
                order: 5
            ),
            InspectionSection(
                id: "section6",
                title: "ANSI/BIFMA X5.5-2014",
                fields: [
                    InspectionField(
                        id: "field6_1",
                        label: "Kiểm tra tiêu chuẩn ANSI",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field6_2",
                        label: "Kiểm tra độ bền",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field6_3",
                        label: "Kiểm tra an toàn",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field6_4",
                        label: "Chứng nhận",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    )
                ],
                order: 6
            )
        ]
    }
    
    static func mock(inspectionId: String = "1", inspectionNumber: String = "001", factoryName: String = "KUKA") -> Inspection {
        Inspection(
            id: inspectionId,
            inspectionNumber: inspectionNumber,
            companyName: "Công ty TNHH ABC",
            productName: "Sản phẩm mẫu",
            productCode: "SP001",
            orderCode: "DH001",
            inspectionType: "Final Inspection",
            quantity: "1000",
            factory: factoryName,
            productionUnit: "Pcs",
            createdAt: Date(),
            inspectorId: nil,
            status: .plan,
            sections: emptyTemplate(),
            orderQuantity: 1000,
            actualCompletedQuantity: 950,
            aqlInspectionQuantity: 80,
            inspectedQuantity: 80
        )
    }
    
    private static func mockSections() -> [InspectionSection] {
        emptyTemplate()
    }
}
