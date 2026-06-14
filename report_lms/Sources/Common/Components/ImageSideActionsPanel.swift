//
//  ImageSideActionsPanel.swift
//  report_lms
//

import SwiftUI

/// Vertical action panel showing Edit / Share / Delete rows, placed beside an image thumbnail.
struct ImageSideActionsPanel: View {
    let onEdit: () -> Void
    let onShare: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ActionRowButton(icon: "pencil", label: "Chỉnh sửa", color: .primary, action: onEdit)
            Divider().padding(.horizontal, 8)
            ActionRowButton(icon: "square.and.arrow.up", label: "Chia sẻ", color: .primary, action: onShare)
            Divider().padding(.horizontal, 8)
            ActionRowButton(icon: "trash", label: "Xoá bỏ", color: .red, action: onDelete)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Action Row Button

private struct ActionRowButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    @GestureState private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .foregroundColor(isPressed ? color.opacity(0.6) : color)
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .background(
                isPressed
                    ? color.opacity(color == .red ? 0.08 : 0.06)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in state = true }
        )
    }
}
