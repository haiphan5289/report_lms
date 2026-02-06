//
//  EmptyErrorView.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import SwiftUI

// MARK: - EmptyErrorView

struct EmptyErrorView: View {
    // MARK: - Constants
    private enum Layout {
        static let spacing: CGFloat = 24
        static let iconSize: CGFloat = 80
        static let titleTopPadding: CGFloat = 20
        static let subtitleTopPadding: CGFloat = 12
        static let subtitleHorizontalPadding: CGFloat = 32
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: Layout.spacing) {
            Spacer()

            contentView

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Private Views
    private var contentView: some View {
        VStack(spacing: 0) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: Layout.iconSize))
                .foregroundColor(.green)

            LMSLabel(
                "Không có Lỗi.",
                style: .title,
                alignment: .center
            )
            .padding(.top, Layout.titleTopPadding)

            LMSLabel(
                "Không có lỗi nào được báo cáo. Để báo cáo lỗi, hãy ấn nút màu đỏ dưới màn hình",
                style: .body,
                color: .secondary,
                alignment: .center
            )
            .multilineTextAlignment(.center)
            .padding(.top, Layout.subtitleTopPadding)
            .padding(.horizontal, Layout.subtitleHorizontalPadding)
        }
    }
}

// MARK: - Preview

#Preview("Empty Error View") {
    EmptyErrorView()
}
