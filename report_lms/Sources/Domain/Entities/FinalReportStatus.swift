//
//  FinalReportStatus.swift
//  report_lms
//
//  Created by GitHub Copilot on 5/3/26.
//

import Foundation

enum FinalReportStatus: String, Codable, CaseIterable {
    case accepted = "Chấp nhận"
    case pending = "Đang chờ xử lý"
    case rejected = "Từ chối"
    
    var displayName: String {
        self.rawValue
    }
    
    var iconName: String {
        switch self {
        case .accepted:
            return "checkmark.circle.fill"
        case .pending:
            return "clock.fill"
        case .rejected:
            return "xmark.circle.fill"
        }
    }

    /// Stable ASCII key sent to the Cloud Function via Firestore.
    var serverKey: String {
        switch self {
        case .accepted: return "accepted"
        case .pending:  return "pending"
        case .rejected: return "rejected"
        }
    }
}
