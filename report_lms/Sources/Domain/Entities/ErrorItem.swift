//
//  ErrorItem.swift
//  report_lms
//
//  Created by GitHub Copilot on 27/1/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import Foundation
import UIKit

// MARK: - ImageSource

enum ImageSource: Equatable {
    case remote(url: String)
    case local(image: UIImage)

    static func == (lhs: ImageSource, rhs: ImageSource) -> Bool {
        switch (lhs, rhs) {
        case (.remote(let l), .remote(let r)): return l == r
        case (.local(let l), .local(let r)): return l === r
        default: return false
        }
    }
}

// MARK: - ImageWithNote

struct ImageWithNote: Identifiable, Equatable {
    let id: UUID
    var source: ImageSource
    var note: String

    init(source: ImageSource, note: String = "") {
        self.id = UUID()
        self.source = source
        self.note = note
    }

    static func == (lhs: ImageWithNote, rhs: ImageWithNote) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - SavedErrorItem

struct SavedErrorItem: Identifiable, Hashable {
    let id: String
    let imageURLs: [String]
    let imageNotes: [String]
    let severity: SeverityLevel
    let generalCondition: Int?
    let defectType: DefectType?
    let comments: String
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        imageURLs: [String] = [],
        imageNotes: [String] = [],
        severity: SeverityLevel = .low,
        generalCondition: Int? = nil,
        defectType: DefectType? = nil,
        comments: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.imageURLs = imageURLs
        self.imageNotes = imageNotes
        self.severity = severity
        self.generalCondition = generalCondition
        self.defectType = defectType
        self.comments = comments
        self.createdAt = createdAt
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "EEE, dd MMM yyyy"
        return formatter.string(from: createdAt)
    }

    func toFirestoreData() -> [String: Any] {
        let formatter = ISO8601DateFormatter()
        var data: [String: Any] = [
            "imageURLs": imageURLs,
            "imageNotes": imageNotes,
            "severity": severity.rawValue,
            "comments": comments,
            "createdAt": formatter.string(from: createdAt)
        ]
        if let gc = generalCondition { data["generalCondition"] = gc }
        if let dt = defectType { data["defectType"] = dt.rawValue }
        return data
    }
}

// MARK: - Error Item Entity (Stub - TODO: Implement properly)
struct ErrorItem: Identifiable {
    let id: String
    let headerText: String
    let defectDescription: String
    let severity: SeverityLevel
    let defectType: DefectType
    let timestamp: Date
    let image: UIImage
    let affectedCount: Int
    let actualMeasurement: Double
    let maxAllowed: Double

    init(
        id: String = UUID().uuidString,
        headerText: String = "Error Header",
        defectDescription: String = "Defect Description",
        severity: SeverityLevel = .low,
        defectType: DefectType = .su1,
        timestamp: Date = Date(),
        image: UIImage = UIImage(),
        affectedCount: Int = 0,
        actualMeasurement: Double = 0.0,
        maxAllowed: Double = 0.0
    ) {
        self.id = id
        self.headerText = headerText
        self.defectDescription = defectDescription
        self.severity = severity
        self.defectType = defectType
        self.timestamp = timestamp
        self.image = image
        self.affectedCount = affectedCount
        self.actualMeasurement = actualMeasurement
        self.maxAllowed = maxAllowed
    }
}

// MARK: - Severity Level
enum SeverityLevel: String, Codable, CaseIterable {
    case low = "Nhẹ"
    case medium = "Nặng"
    case critical = "Nghiêm trọng"

    var displayName: String {
        self.rawValue
    }
}

// MARK: - Defect Type
enum DefectType: String, Codable, CaseIterable {
    // PA - Đóng gói sản phẩm
    case pa1 = "PA-1"
    case pa2 = "PA-2"
    case pa3 = "PA-3"
    case pa4 = "PA-4"
    case pa5 = "PA-5"
    case pa6 = "PA-6"
    case pa7 = "PA-7"
    case pa8 = "PA-8"
    case pa9 = "PA-9"
    case pa10 = "PA-10"
    case pa11 = "PA-11"
    case pa12 = "PA-12"
    case pa13 = "PA-13"
    case pa14 = "PA-14"
    case pa15 = "PA-15"
    case pa16 = "PA-16"
    case pa17 = "PA-17"
    case pa18 = "PA-18"
    case pa19 = "PA-19"
    case pa20 = "PA-20"
    case pa21 = "PA-21"
    case pa22 = "PA-22"
    case pa23 = "PA-23"
    case pa24 = "PA-24"
    case pa25 = "PA-25"
    // SU - Bề mặt sản phẩm
    case su1 = "SU-1"
    case su2 = "SU-2"
    case su3 = "SU-3"
    case su4 = "SU-4"
    case su5 = "SU-5"
    case su6 = "SU-6"
    case su7 = "SU-7"
    case su8 = "SU-8"
    case su9 = "SU-9"
    case su10 = "SU-10"
    case su11 = "SU-11"
    // AS - Lắp ráp
    case as1 = "AS-1"
    case as2 = "AS-2"
    case as3 = "AS-3"
    case as4 = "AS-4"
    case as5 = "AS-5"
    case as6 = "AS-6"
    case as7 = "AS-7"
    case as8 = "AS-8"
    case as9 = "AS-9"
    // FU - Chức năng và kiểm tra
    case fu1 = "FU-1"
    case fu2 = "FU-2"
    case fu3 = "FU-3"
    case fu4 = "FU-4"
    case fu5 = "FU-5"
    case fu6 = "FU-6"
    case fu7 = "FU-7"
    case fu8 = "FU-8"
    case fu9 = "FU-9"
    case fu10 = "FU-10"
    case fu11 = "FU-11"
    case fu12 = "FU-12"
    case fu13 = "FU-13"
    // SA - An toàn
    case sa1 = "SA-1"
    case sa2 = "SA-2"
    case sa3 = "SA-3"
    case sa4 = "SA-4"
    case sa5 = "SA-5"
    // FI - Finishing
    case fi1 = "FI-1"
    case fi2 = "FI-2"
    case fi3 = "FI-3"
    case fi4 = "FI-4"
    case fi5 = "FI-5"
    case fi6 = "FI-6"
    case fi7 = "FI-7"
    case fi8 = "FI-8"
    case fi9 = "FI-9"
    case fi10 = "FI-10"
    case fi11 = "FI-11"
    case fi12 = "FI-12"
    case fi13 = "FI-13"
    case fi14 = "FI-14"
    case fi15 = "FI-15"
    case fi16 = "FI-16"
    case fi17 = "FI-17"
    case fi18 = "FI-18"
    case fi19 = "FI-19"
    case fi20 = "FI-20"
    case fi21 = "FI-21"
    case fi22 = "FI-22"
    case fi23 = "FI-23"
    case fi24 = "FI-24"
    // CO - Construction
    case co1 = "CO-1"
    case co2 = "CO-2"
    case co3 = "CO-3"
    case co4 = "CO-4"
    case co5 = "CO-5"
    case co6 = "CO-6"
    case co7 = "CO-7"
    case co8 = "CO-8"
    case co9 = "CO-9"
    case co10 = "CO-10"
    case co11 = "CO-11"
    case co12 = "CO-12"
    case co13 = "CO-13"
    case co14 = "CO-14"
    case co15 = "CO-15"
    case co16 = "CO-16"
    case co17 = "CO-17"
    // FE - Features
    case fe1 = "FE-1"
    case fe2 = "FE-2"
    case fe3 = "FE-3"
    case fe4 = "FE-4"
    case fe5 = "FE-5"
    case fe6 = "FE-6"
    case fe7 = "FE-7"
    case fe8 = "FE-8"
    case fe9 = "FE-9"
    case fe10 = "FE-10"
    case fe11 = "FE-11"
    // TA - Tailoring
    case ta1 = "TA-1"
    case ta2 = "TA-2"
    case ta3 = "TA-3"
    case ta4 = "TA-4"
    case ta5 = "TA-5"
    case ta6 = "TA-6"
    case ta7 = "TA-7"
    case ta8 = "TA-8"
    case ta9 = "TA-9"
    case ta10 = "TA-10"
    case ta11 = "TA-11"

    var name: String {
        switch self {
        // PA
        case .pa1: return "Thiếu cảnh báo và ký hiệu an toàn"
        case .pa2: return "Hướng dẫn lắp ráp"
        case .pa3: return "Bao nylon không đục lỗ"
        case .pa4: return "Thông tin bao bì và nhãn dán"
        case .pa5: return "Đóng gói: dán kín và chặt"
        case .pa6: return "Sai mã vạch và thông tin đơn hàng"
        case .pa7: return "Bảo vệ góc"
        case .pa8: return "Test đóng gói"
        case .pa9: return "Thùng carton bị hư hỏng, ẩm ướt, đè nát, biến dạng"
        case .pa10: return "Kích thước và cân nặng"
        case .pa11: return "Vật lạ (côn trùng, sâu bọ, v.v)"
        case .pa12: return "Mùi hôi"
        case .pa13: return "Ray trượt không có che chắn chống trượt"
        case .pa14: return "Không có mút carton góc"
        case .pa15: return "Vật tư đóng gói ngắn, k đúng kích thước"
        case .pa16: return "Chân không được quấn trong bao bong bóng"
        case .pa17: return "Chân không được bỏ trong ngăn trống với dây kéo"
        case .pa18: return "Thiếu vật tư điện nếu có"
        case .pa19: return "Không có bịch chống ẩm"
        case .pa20: return "Gối không được bỏ vào bao ni lông"
        case .pa21: return "Đóng gói không chặt, di chuyển trong thùng"
        case .pa22: return "Không có màng foam hay giấy lót bảo vệ tay"
        case .pa23: return "Không có màng foam hay giấy lót bảo vệ lưng"
        case .pa24: return "Carton góc không có"
        case .pa25: return "Khác"
        // SU
        case .su1: return "Thiếu lớp phủ/sơn/phun/in/sơn tĩnh điện"
        case .su2: return "Sai hình dạng, biến dạng và không đối xứng"
        case .su3: return "Bề mặt không bằng phẳng và mức độ không đồng đều"
        case .su4: return "Trầy xước, cấn móp, mè cạnh"
        case .su5: return "Bụi bẩn và các vết (keo, vết lõm, sứt mẻ, rạn nứt)"
        case .su6: return "Thiếu mối hàn"
        case .su7: return "Thiếu chà nhám"
        case .su8: return "Gỉ sét"
        case .su9: return "Nứt"
        case .su10: return "Dung sai mắt chết"
        case .su11: return "Khác"
        // AS
        case .as1: return "Lắp ráp chưa hoàn chỉnh"
        case .as2: return "Sai hoặc thiếu phụ kiện"
        case .as3: return "Chi tiết và phụ kiện lắp ráp không phù hợp"
        case .as4: return "Hở mối ghép"
        case .as5: return "Các phần nối không thẳng"
        case .as6: return "Kết nối lỏng lẻo"
        case .as7: return "Thiếu ốc để ráp chân"
        case .as8: return "Hướng dẫn lắp ráp không đúng"
        case .as9: return "Khác"
        // FU
        case .fu1: return "Kiểm tra tải"
        case .fu2: return "Không ổn định"
        case .fu3: return "Độ ẩm và nấm"
        case .fu4: return "Tiếng ồn không cần thiết"
        case .fu5: return "Ghế bạt không hoạt động dễ dàng"
        case .fu6: return "Đỡ chân không đẩy ra dễ dàng"
        case .fu7: return "Đỡ chân không chắc chắn"
        case .fu8: return "Ghế bạt điện không hoạt động trơn tru ở tất cả các vị trí"
        case .fu9: return "USB không hoạt động"
        case .fu10: return "Bluetooth không hoạt động"
        case .fu11: return "Nắp cửa console không đứng yên khi nâng lên"
        case .fu12: return "Phần đính kèm không hoạt động tốt"
        case .fu13: return "Khác"
        // SA
        case .sa1: return "Mảnh vụn"
        case .sa2: return "Cạnh/Điểm bén nhọn"
        case .sa3: return "Thiếu cảnh báo"
        case .sa4: return "Vật liệu chống cháy"
        case .sa5: return "Khác"
        // FI
        case .fi1: return "Tróc, chảy, phồng độp"
        case .fi2: return "Dấu vân tay, sần"
        case .fi3: return "Khu vực không có màu"
        case .fi4: return "Màu không đồng nhất"
        case .fi5: return "Giả cổ ngẫu nhiên"
        case .fi6: return "Xử lý gỗ"
        case .fi7: return "Dính keo"
        case .fi8: return "Không có sơn/sản ở liên kết"
        case .fi9: return "Sơn trong lòng hộc kéo"
        case .fi10: return "Không quá nhiều mắt trên mặt"
        case .fi11: return "Không quá nhiều mắt trên hông"
        case .fi12: return "Không quá nhiều mắt trên mặt hộc kéo"
        case .fi13: return "Nứt trên mắt gỗ"
        case .fi14: return "Đinh/vít phồng"
        case .fi15: return "Lỗ đinh"
        case .fi16: return "Công vênh ở mặt/hông"
        case .fi17: return "Chà nhám lõm"
        case .fi18: return "Mặt hộc không thẳng"
        case .fi19: return "Võng mặt/hông"
        case .fi20: return "Trầy veneer"
        case .fi21: return "Không khớp chiều veneer"
        case .fi22: return "Tróc veneer"
        case .fi23: return "Nhám cạnh"
        case .fi24: return "Khác"
        // CO
        case .co1: return "Mối ghép phẳng"
        case .co2: return "Khe hở o mới ghép"
        case .co3: return "Ghép không thẳng"
        case .co4: return "Keo/dầu/trầy trên nỉ"
        case .co5: return "Nứt trong hộc kéo"
        case .co6: return "Ke gốc cho khung"
        case .co7: return "Khung đỡ hộc"
        case .co8: return "Khung đỡ hộc khi loại bỏ hộc kéo"
        case .co9: return "Hộc kéo đóng/mở không dễ dàng"
        case .co10: return "Cửa đóng/mở không dễ dàng"
        case .co11: return "Độ ngã không đúng"
        case .co12: return "Thiếu foam ở lưng, tay, ngồi"
        case .co13: return "Khung bị võng ở giữa"
        case .co14: return "Lưng tựa không có gia cố"
        case .co15: return "Nệm không có cố định"
        case .co16: return "Nệm không có 2 mặt"
        case .co17: return "Khác"
        // FE
        case .fe1: return "Chiều sâu hộc kéo không đều"
        case .fe2: return "Không có ván bắn ở phía sau để chống lật"
        case .fe3: return "Không có ván ngăn bụi giữa các hộc kéo"
        case .fe4: return "Đinh trang trí không thẳng"
        case .fe5: return "Đinh trang trí không đều khoảng cách"
        case .fe6: return "Mặt đá có dính nhựa sửa"
        case .fe7: return "Mặt đá khác màu"
        case .fe8: return "Bọc nệm không chặt"
        case .fe9: return "Không có đủ chất độn"
        case .fe10: return "Nhăn, hở ở cạnh/nút"
        case .fe11: return "Khác"
        // TA
        case .ta1: return "Đường may không thẳng"
        case .ta2: return "Chỉ không chặt chẽ trong đường may"
        case .ta3: return "Chỉ lỏng lẻo"
        case .ta4: return "Đường viền không thẳng"
        case .ta5: return "Vải không bó chặt vào khung"
        case .ta6: return "Vết nhăn trên da"
        case .ta7: return "Đường chỉ không thẳng"
        case .ta8: return "Rách"
        case .ta9: return "Đường may, đường khâu bị bung và đầu sợi chỉ thừa chưa được cắt"
        case .ta10: return "Bọc không đạt"
        case .ta11: return "Khác"
        }
    }

    var displayName: String {
        "\(rawValue) - \(name)"
    }

    var category: String {
        String(rawValue.prefix(2))
    }

    var categoryDisplayName: String {
        switch category {
        case "PA": return "PA - Đóng gói sản phẩm"
        case "SU": return "SU - Bề mặt sản phẩm"
        case "AS": return "AS - Lắp ráp"
        case "FU": return "FU - Chức năng và kiểm tra"
        case "SA": return "SA - An toàn"
        case "FI": return "FI - Finishing"
        case "CO": return "CO - Construction"
        case "FE": return "FE - Features"
        case "TA": return "TA - Tailoring"
        default: return category
        }
    }
}
