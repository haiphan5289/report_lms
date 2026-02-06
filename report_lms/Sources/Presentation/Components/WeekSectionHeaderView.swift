//
//  WeekSectionHeaderView.swift
//  report_lms
//
//  Created by GitHub Copilot on 27/1/26.
//

import SwiftUI

struct WeekSectionHeaderView: View {
    // MARK: - Properties
    let section: WeekSection
    let isExpanded: Bool
    let showExpandButton: Bool
    let onToggle: () -> Void

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Header with title
            HStack {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)

                LMSLabel(section.title,
                        style: .subheadline,
                        color: .secondary)

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground))

            // Expand button at bottom of section
            if showExpandButton && isExpanded {
                expandButton
            }
        }
    }

    // MARK: - Private Views
    private var expandButton: some View {
        Button(action: onToggle) {
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    LMSLabel("HIỆN THỊ TẤT CẢ",
                            style: .caption,
                            color: .custom(Color.blue))
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview("This Week - Collapsed") {
    WeekSectionHeaderView(
        section: WeekSection(
            id: "this_week",
            title: "TUẦN NÀY (3)",
            weekStartDate: Date(),
            inspections: []
        ),
        isExpanded: false,
        showExpandButton: true,
        onToggle: {}
    )
}

#Preview("This Week - Expanded") {
    WeekSectionHeaderView(
        section: WeekSection(
            id: "this_week",
            title: "TUẦN NÀY (3)",
            weekStartDate: Date(),
            inspections: []
        ),
        isExpanded: true,
        showExpandButton: true,
        onToggle: {}
    )
}

#Preview("Last Week") {
    WeekSectionHeaderView(
        section: WeekSection(
            id: "last_week",
            title: "TUẦN TRƯỚC (5)",
            weekStartDate: Date().addingTimeInterval(-7 * 24 * 60 * 60),
            inspections: []
        ),
        isExpanded: false,
        showExpandButton: true,
        onToggle: {}
    )
}
