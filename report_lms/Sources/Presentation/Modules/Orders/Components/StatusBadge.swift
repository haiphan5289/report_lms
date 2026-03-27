//
//  StatusBadge.swift
//  report_lms
//

import SwiftUI

struct StatusBadge: View {
    let status: InspectionStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.accentColor)
                .frame(width: 6, height: 6)
            LMSLabel(status.displayName, style: .caption, color: .custom(status.accentColor))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.accentColor.opacity(0.12))
        .cornerRadius(20)
    }
}

#Preview {
    HStack(spacing: 8) {
        StatusBadge(status: .plan)
        StatusBadge(status: .inProgress)
        StatusBadge(status: .completed)
        StatusBadge(status: .error)
        StatusBadge(status: .cancelled)
    }
    .padding()
}
