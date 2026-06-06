//
//  DeleteConfirmationView.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/1/26.
//

import SwiftUI

struct DeleteConfirmationView: View {
    let title: String
    let message: String
    let confirmTitle: String
    let confirmAction: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Staggered entrance
    @State private var iconVisible = false
    @State private var textVisible = false
    @State private var buttonsVisible = false

    // Icon danger pulse
    @State private var pulseScale: CGFloat = 1.0

    // Tap press states
    @GestureState private var cancelPressed = false
    @GestureState private var deletePressed = false

    var body: some View {
        VStack(spacing: 24) {
            iconSection
            textSection
            buttonSection
        }
        .task {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { iconVisible = true }
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeOut(duration: 0.35)) { textVisible = true }
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeOut(duration: 0.35)) { buttonsVisible = true }
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }
        }
    }

    // MARK: - Icon

    private var iconSection: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.06))
                .frame(width: 96, height: 96)
                .scaleEffect(pulseScale)

            Circle()
                .fill(Color.red.opacity(0.12))
                .frame(width: 72, height: 72)

            Image(systemName: "trash.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, Color(red: 0.85, green: 0.1, blue: 0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .padding(.top, 8)
        .opacity(iconVisible ? 1 : 0)
        .scaleEffect(iconVisible ? 1 : 0.5)
    }

    // MARK: - Text

    private var textSection: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.system(size: 19, weight: .bold))
                .foregroundColor(.primary)
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .opacity(textVisible ? 1 : 0)
        .offset(y: textVisible ? 0 : 10)
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        HStack(spacing: 12) {
            cancelButton
            deleteButton
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .opacity(buttonsVisible ? 1 : 0)
        .offset(y: buttonsVisible ? 0 : 14)
    }

    private var cancelButton: some View {
        Button(action: { dismiss() }) {
            Text("Hủy")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                )
        }
        .scaleEffect(cancelPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: cancelPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($cancelPressed) { _, state, _ in state = true }
        )
    }

    private var deleteButton: some View {
        Button(action: { confirmAction(); dismiss() }) {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                Text(confirmTitle)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.22, blue: 0.22), Color.red.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: Color.red.opacity(deletePressed ? 0.25 : 0.45),
                        radius: deletePressed ? 4 : 12,
                        x: 0,
                        y: deletePressed ? 2 : 6
                    )
            )
        }
        .scaleEffect(deletePressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: deletePressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($deletePressed) { _, state, _ in state = true }
        )
    }
}

// MARK: - Preview

#Preview {
    DeleteConfirmationView(
        title: "Xóa ảnh",
        message: "Bạn có chắc chắn muốn xóa ảnh này không?",
        confirmTitle: "Xóa"
    ) {
        print("Deleted")
    }
}

#Preview("Long Message") {
    DeleteConfirmationView(
        title: "Xóa tất cả ảnh",
        message: "Bạn có chắc chắn muốn xóa tất cả các ảnh đã chụp không? Hành động này không thể hoàn tác.",
        confirmTitle: "Xóa tất cả"
    ) {
        print("Deleted")
    }
}
