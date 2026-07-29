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
    var imageURLs: [String]
    /// Parallel array to imageURLs — per-image caption entered by inspector.
    var imageDescriptions: [String]
    /// Parallel array to imageURLs — per-image size measurement in millimeters entered by inspector.
    var imageMeasurementsMM: [String]
    let isRequired: Bool

    enum FieldType: String, Codable {
        case text
        case photo
        case checkbox
        case number
    }

    enum CodingKeys: String, CodingKey {
        case id, label, type, photoURL, imageURLs, imageDescriptions, imageMeasurementsMM, isRequired
    }

    init(id: String, label: String, type: FieldType, photoURL: String? = nil, imageURLs: [String] = [], imageDescriptions: [String] = [], imageMeasurementsMM: [String] = [], isRequired: Bool) {
        self.id = id
        self.label = label
        self.type = type
        self.photoURL = photoURL
        self.imageURLs = imageURLs
        self.imageDescriptions = imageDescriptions
        self.imageMeasurementsMM = imageMeasurementsMM
        self.isRequired = isRequired
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        label = try container.decode(String.self, forKey: .label)
        type = try container.decode(FieldType.self, forKey: .type)
        photoURL = try container.decodeIfPresent(String.self, forKey: .photoURL)
        imageURLs = (try? container.decodeIfPresent([String].self, forKey: .imageURLs)) ?? []
        imageDescriptions = (try? container.decodeIfPresent([String].self, forKey: .imageDescriptions)) ?? []
        imageMeasurementsMM = (try? container.decodeIfPresent([String].self, forKey: .imageMeasurementsMM)) ?? []
        isRequired = try container.decode(Bool.self, forKey: .isRequired)
    }
}

// MARK: - Localization Extensions

extension InspectionSection {
    func localizedTitle(using manager: LocalizationManager) -> String {
        let key = "inspection.section.\(id)"
        let resolved = manager.localize(key)
        return resolved == key ? title : resolved
    }
}

extension InspectionField {
    func localizedLabel(using manager: LocalizationManager) -> String {
        let key = "inspection.field.\(id)"
        let resolved = manager.localize(key)
        return resolved == key ? label : resolved
    }
}

// MARK: - Mock Data Extension
//

extension Inspection {
    /// Returns empty sections template for new inspections
    static func emptyTemplate() -> [InspectionSection] {
        [
            InspectionSection(
                id: "section1",
                title: "Outer Carton",
                fields: [
                    InspectionField(
                        id: "field1_1",
                        label: "Carton overview",
                        type: .photo,
                        photoURL: nil,
                        isRequired: true
                    ),
                    InspectionField(
                        id: "field1_2",
                        label: "Shipping mark info",
                        type: .photo,
                        photoURL: nil,
                        isRequired: true
                    )
                ],
                order: 1
            ),
            InspectionSection(
                id: "section2",
                title: "Inner carton",
                fields: [
                    InspectionField(
                        id: "field2_1",
                        label: "Inner carton overview",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field2_2",
                        label: "Packaging (corner protection, filter, hardware, silica gel...)",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    )
                ],
                order: 2
            ),
            InspectionSection(
                id: "section3",
                title: "Product",
                fields: [
                    InspectionField(
                        id: "field3_1",
                        label: "Product view",
                        type: .photo,
                        photoURL: nil,
                        isRequired: true
                    ),
                    InspectionField(
                        id: "field3_2",
                        label: "Compare with approved sample (weight, style, finish, comfort...)",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field3_3",
                        label: "Product dimension",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field3_4",
                        label: "Logo on product",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field3_5",
                        label: "Product label (Tip label, warning label)",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field3_6",
                        label: "Assembly instruction",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field3_7",
                        label: "Moisture Readings",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field3_8",
                        label: "Sheen Readings",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field3_9",
                        label: "Color Comparison",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    )
                ],
                order: 3
            ),
            InspectionSection(
                id: "section4",
                title: "ANSI/BIFMA X5.5-2014",
                fields: [
                    InspectionField(
                        id: "field4_1",
                        label: "Weight of weights",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field4_2",
                        label: "Pictures of the weights to be applied",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field4_3",
                        label: "Pictures of the weights on the table in the correct position",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    ),
                    InspectionField(
                        id: "field4_4",
                        label: "Data to enter should be the amount of weight and pass/fail",
                        type: .photo,
                        photoURL: nil,
                        isRequired: false
                    )
                ],
                order: 4
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
