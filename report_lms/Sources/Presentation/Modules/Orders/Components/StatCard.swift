//
//  StatCard.swift
//  report_lms
//

import SwiftUI

struct StatCard: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        LMSSectionContainer(
            backgroundColor: LMSColor.background,
            cornerRadius: 10,
            padding: 12
        ) {
            VStack(spacing: 4) {
                LMSLabel("\(value)", style: .title2, color: .custom(color))
                LMSLabel(label, style: .caption, color: .secondary, lineLimit: 1)
            }
            .frame(maxWidth: .infinity)
        }
        .shadow(color: LMSColor.Shadow.subtle, radius: 3, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    HStack(spacing: 10) {
        StatCard(value: 12, label: "Tất cả", color: .blue)
        StatCard(value: 5, label: "Kế hoạch", color: .blue)
        StatCard(value: 4, label: "Đang KT", color: .orange)
        StatCard(value: 3, label: "Hoàn thành", color: .green)
    }
    .padding()
}
