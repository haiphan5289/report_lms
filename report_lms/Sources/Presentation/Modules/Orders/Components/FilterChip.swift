//
//  FilterChip.swift
//  report_lms
//

import SwiftUI

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        LMSButton(label, variant: isSelected ? .primary : .secondary, size: .small, action: action)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    HStack(spacing: 8) {
        FilterChip(label: "Tất cả", isSelected: true, action: {})
        FilterChip(label: "Kế hoạch", isSelected: false, action: {})
        FilterChip(label: "Hoàn thành", isSelected: false, action: {})
    }
    .padding()
}
