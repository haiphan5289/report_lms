//
//  LMSLoadingOverlay.swift
//  report_lms
//
//  Created by GitHub Copilot on 1/2/26.
//

import SwiftUI

/// Overlay loading view for form submissions and blocking actions
/// Dims background and prevents user interaction during operations
struct LMSLoadingOverlay: View {
    // MARK: - Properties
    let message: String
    let backgroundColor: Color
    let foregroundColor: Color

    // MARK: - Initialization
    init(
        message: String = "Đang tải...",
        backgroundColor: Color = Color(.systemGray),
        foregroundColor: Color = .white
    ) {
        self.message = message
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(foregroundColor)

                LMSLabel(
                    message,
                    style: .body,
                    color: .custom(foregroundColor)
                )
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Preview
#Preview("Default") {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        LMSLoadingOverlay()
    }
}

#Preview("Custom Message") {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        LMSLoadingOverlay(message: "Đang gửi dữ liệu...")
    }
}

#Preview("Custom Colors") {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        LMSLoadingOverlay(
            message: "Đang xử lý...",
            backgroundColor: .blue,
            foregroundColor: .white
        )
    }
}

#Preview("Dark Mode") {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        LMSLoadingOverlay()
    }
    .preferredColorScheme(.dark)
}
