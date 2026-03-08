//
//  LMSLoadingOverlay.swift
//  report_lms
//
//  Created by GitHub Copilot on 1/2/26.
//

import SwiftUI

/// Style variants for loading overlay
enum LMSLoadingOverlayStyle {
    case light
    case dark
    case custom(backgroundColor: Color, foregroundColor: Color, overlayOpacity: Double, progressScale: CGFloat)
    
    var backgroundColor: Color {
        switch self {
        case .light: return Color(.systemGray)
        case .dark: return Color.black.opacity(0.8)
        case .custom(let bg, _, _, _): return bg
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .light, .dark: return .white
        case .custom(_, let fg, _, _): return fg
        }
    }
    
    var overlayOpacity: Double {
        switch self {
        case .light: return 0.3
        case .dark: return 0.4
        case .custom(_, _, let opacity, _): return opacity
        }
    }
    
    var progressScale: CGFloat {
        switch self {
        case .light: return 1.0
        case .dark: return 1.5
        case .custom(_, _, _, let scale): return scale
        }
    }
    
    var padding: CGFloat {
        switch self {
        case .light: return 24
        case .dark: return 30
        case .custom: return 24
        }
    }
    
    var cornerRadius: CGFloat {
        switch self {
        case .light: return 12
        case .dark: return 16
        case .custom: return 12
        }
    }
}

/// Overlay loading view for form submissions and blocking actions
/// Dims background and prevents user interaction during operations
struct LMSLoadingOverlay: View {
    // MARK: - Properties
    let message: String
    let style: LMSLoadingOverlayStyle

    // MARK: - Initialization
    init(
        message: String = "Đang tải...",
        style: LMSLoadingOverlayStyle = .light
    ) {
        self.message = message
        self.style = style
    }
    
    // Backward compatibility initializer
    init(
        message: String = "Đang tải...",
        backgroundColor: Color = Color(.systemGray),
        foregroundColor: Color = .white
    ) {
        self.message = message
        self.style = .custom(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            overlayOpacity: 0.3,
            progressScale: 1.0
        )
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            Color.black.opacity(style.overlayOpacity)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(style.progressScale)
                    .tint(style.foregroundColor)

                LMSLabel(
                    message,
                    style: .body,
                    color: .custom(style.foregroundColor)
                )
            }
            .padding(style.padding)
            .background(
                RoundedRectangle(cornerRadius: style.cornerRadius)
                    .fill(style.backgroundColor)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
}

// MARK: - Preview
#Preview("Light Style") {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        LMSLoadingOverlay(message: "Đang tải...", style: .light)
    }
}

#Preview("Dark Style") {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        LMSLoadingOverlay(message: "Đang tạo PDF...", style: .dark)
    }
}

#Preview("Custom Message Light") {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        LMSLoadingOverlay(message: "Đang gửi dữ liệu...", style: .light)
    }
}

#Preview("Custom Message Dark") {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        LMSLoadingOverlay(message: "Đang lưu ảnh...", style: .dark)
    }
}

#Preview("Custom Style") {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        LMSLoadingOverlay(
            message: "Đang xử lý...",
            style: .custom(
                backgroundColor: .blue,
                foregroundColor: .white,
                overlayOpacity: 0.5,
                progressScale: 1.2
            )
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
