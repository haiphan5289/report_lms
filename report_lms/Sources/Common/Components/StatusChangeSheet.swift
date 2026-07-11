//
//  StatusChangeSheet.swift
//  report_lms
//

import SwiftUI

/// Bottom sheet for manually changing an inspection's status.
/// Styled after `DeleteConfirmationView` (staggered entrance, icon header,
/// cancel/confirm pair) with a 5-row status picker in between.
struct StatusChangeSheet: View {
    let title: String
    let message: String
    let confirmTitle: String
    let currentStatus: InspectionStatus
    let confirmAction: (InspectionStatus) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedStatus: InspectionStatus?

    // Staggered entrance
    @State private var iconVisible = false
    @State private var textVisible = false
    @State private var listVisible = false
    @State private var buttonsVisible = false

    private var canConfirm: Bool {
        guard let selected = selectedStatus else { return false }
        return selected != currentStatus
    }

    var body: some View {
        VStack(spacing: 20) {
            iconSection
            textSection
            statusList
            buttonSection
        }
        .task {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { iconVisible = true }
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeOut(duration: 0.35)) { textVisible = true }
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeOut(duration: 0.35)) { listVisible = true }
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeOut(duration: 0.35)) { buttonsVisible = true }
        }
    }

    // MARK: - Icon

    private var iconSection: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.06))
                .frame(width: 80, height: 80)

            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 60, height: 60)

            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, Color(red: 0.1, green: 0.3, blue: 0.85)],
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
        VStack(spacing: 8) {
            LMSLabel(title, style: .headline)
            LMSLabel(message, style: .subheadline, color: .secondary, alignment: .center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .opacity(textVisible ? 1 : 0)
        .offset(y: textVisible ? 0 : 10)
    }

    // MARK: - Status List

    private var statusList: some View {
        VStack(spacing: 8) {
            ForEach(InspectionStatus.allCases, id: \.self) { status in
                statusRow(status)
            }
        }
        .padding(.horizontal, 24)
        .opacity(listVisible ? 1 : 0)
        .offset(y: listVisible ? 0 : 12)
    }

    private func statusRow(_ status: InspectionStatus) -> some View {
        let isSelected = selectedStatus == status
        let isCurrent = status == currentStatus

        return Button {
            selectedStatus = isSelected ? nil : status
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(status.accentColor)
                    .frame(width: 8, height: 8)

                LMSLabel(status.displayName, style: .body)

                if isCurrent {
                    LMSLabel("Hiện tại", style: .caption, color: .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .cornerRadius(6)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .blue : Color(.systemGray4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.08) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue.opacity(0.4) : Color(.systemGray4).opacity(0.5),
                                    lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(isCurrent)
        .opacity(isCurrent ? 0.55 : 1)
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        HStack(spacing: 12) {
            cancelButton
            confirmButton
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
        .buttonStyle(PressScaleButtonStyle())
    }

    private var confirmButton: some View {
        Button(action: {
            guard let selected = selectedStatus else { return }
            confirmAction(selected)
            dismiss()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
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
                            colors: canConfirm
                                ? [Color(red: 0.2, green: 0.5, blue: 1.0), Color.blue.opacity(0.85)]
                                : [Color(.systemGray4), Color(.systemGray4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: canConfirm ? Color.blue.opacity(0.35) : .clear,
                        radius: 10, x: 0, y: 5
                    )
            )
        }
        .buttonStyle(PressScaleButtonStyle())
        .disabled(!canConfirm)
    }
}

// MARK: - Press Scale Button Style

/// Press feedback via ButtonStyle — never `.animation(value:)` on Button ancestors.
private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    Text("Tap me")
        .sheet(isPresented: .constant(true)) {
            StatusChangeSheet(
                title: "Đổi trạng thái",
                message: "Chọn trạng thái mới cho \"INS-2026-001\"",
                confirmTitle: "Xác nhận",
                currentStatus: .inProgress
            ) { newStatus in
                print("Changed to \(newStatus.rawValue)")
            }
            .presentationDetents([.height(620)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
}
