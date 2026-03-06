//
//  InspectionDetail.swift
//  report_lms
//
//  Created by GitHub Copilot on 1/2/26.
//

import Foundation

struct InspectionDetail: Identifiable {
    let id: String
    let inspectionNumber: String
    let sections: [InspectionSection]
    
    // Quantity Information
    let orderQuantity: Int
    let actualCompletedQuantity: Int
    let aqlInspectionQuantity: Int
    let inspectedQuantity: Int
    
    // Factory Information
    let factoryName: String
}

struct InspectionSection: Identifiable {
    let id: String
    let title: String
    let fields: [InspectionField]
    let order: Int

    var itemCount: Int {
        fields.count
    }
}

struct InspectionField: Identifiable {
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
extension InspectionDetail {
    static func mock(inspectionId: String, inspectionNumber: String, factoryName: String = "KUKA") -> InspectionDetail {
        InspectionDetail(
            id: inspectionId,
            inspectionNumber: inspectionNumber,
            sections: [
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
            ],
            orderQuantity: 5000,
            actualCompletedQuantity: 4800,
            aqlInspectionQuantity: 315,
            inspectedQuantity: 315,
            factoryName: factoryName
        )
    }
}
