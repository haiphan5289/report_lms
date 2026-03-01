//
//  ValidationStatus.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/1/26.
//

import Foundation

/// Validation status for inspection field
enum ValidationStatus: String, Codable {
    case passed = "Đã kiểm tra - Đạt"
    case failed = "Đã kiểm tra - Không đạt"
    case pending = "Đang chờ xử lý"
    case notApplicable = "Không áp dụng"
    
    var displayText: String {
        return self.rawValue
    }
}
