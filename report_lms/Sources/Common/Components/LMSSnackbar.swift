//
//  LMSSnackbar.swift
//  report_lms
//

import SwiftUI

// MARK: - Snackbar Type

enum LMSSnackbarType {
    case success
    case error
    case info

    var backgroundColor: Color {
        switch self {
        case .success: return Color(.systemGreen)
        case .error:   return LMSColor.destructive
        case .info:    return LMSColor.primary
        }
    }

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .info:    return "info.circle.fill"
        }
    }
}

// MARK: - LMSSnackbar View

struct LMSSnackbar: View {
    let message: String
    let type: LMSSnackbarType

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(type.backgroundColor)
        .cornerRadius(10)
        .shadow(color: LMSColor.Shadow.medium, radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
    }
}

// MARK: - ViewModifier

private struct SnackbarModifier: ViewModifier {
    @Binding var message: String?
    let type: LMSSnackbarType
    let duration: TimeInterval

    @State private var isVisible = false
    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        ZStack(alignment: .bottom) {
            content

            if isVisible, let msg = message {
                LMSSnackbar(message: msg, type: type)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 12)
                    .zIndex(999)
            }
        }
        .onChange(of: message) { _, newValue in
            if newValue != nil {
                show()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
    }

    private func show() {
        dismissTask?.cancel()
        isVisible = true
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                isVisible = false
                message = nil
            }
        }
    }
}

// MARK: - View Extension

extension View {
    /// Shows a snackbar at the bottom of the view when `message` is non-nil.
    /// Auto-dismisses after `duration` seconds and resets `message` to nil.
    func lmsSnackbar(
        message: Binding<String?>,
        type: LMSSnackbarType = .success,
        duration: TimeInterval = 2.5
    ) -> some View {
        modifier(SnackbarModifier(message: message, type: type, duration: duration))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        LMSSnackbar(message: "Ảnh đã được lưu thành công!", type: .success)
        LMSSnackbar(message: "Không thể tải ảnh lên. Vui lòng thử lại.", type: .error)
        LMSSnackbar(message: "Đang đồng bộ dữ liệu...", type: .info)
    }
    .padding(.vertical)
    .background(Color(.systemGroupedBackground))
}
