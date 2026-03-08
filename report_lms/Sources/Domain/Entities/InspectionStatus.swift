//
//  InspectionStatus.swift
//  report_lms
//
//  Created by GitHub Copilot on 27/1/26.
//

import Foundation

enum InspectionStatus: String, Codable {
    case plan = "Kế hoạch"
    case inProgress = "Đang kiểm tra"
    case error = "Có lỗi"
    case completed = "Hoàn thành"
    case cancelled = "Đã hủy"

    var displayName: String {
        self.rawValue
    }
}
