//
//  InspectionStatus+Orders.swift
//  report_lms
//

import SwiftUI

extension InspectionStatus: CaseIterable {
    public static var allCases: [InspectionStatus] {
        [.plan, .inProgress, .completed, .error, .cancelled]
    }

    var accentColor: Color {
        switch self {
        case .plan:       return .blue
        case .inProgress: return .orange
        case .completed:  return .green
        case .error:      return .red
        case .cancelled:  return Color(.systemGray)
        }
    }
}
