//
//  InspectionDetailBottomSheet.swift
//  report_lms
//

import SwiftUI

struct InspectionDetailBottomSheet: View {
    // MARK: - Properties
    let inspection: Inspection
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingDeleteConfirm = false

    // Progressive reveal
    @State private var headerVisible = false
    @State private var infoVisible = false
    @State private var actionsVisible = false

    // Tap scale feedback
    @GestureState private var deletePressed = false

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            dragIndicator

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    heroHeader
                        .opacity(headerVisible ? 1 : 0)
                        .offset(y: headerVisible ? 0 : 16)
                        .animation(.easeOut(duration: 0.4), value: headerVisible)

                    infoSection
                        .opacity(infoVisible ? 1 : 0)
                        .offset(y: infoVisible ? 0 : 16)
                        .animation(.easeOut(duration: 0.4), value: infoVisible)

                    // Bottom spacer so content doesn't hide behind pinned actions
                    Spacer(minLength: 96)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
        }
        .background(Color(.systemBackground))
        .safeAreaInset(edge: .bottom) {
            actionBar
                .opacity(actionsVisible ? 1 : 0)
                .offset(y: actionsVisible ? 0 : 20)
                .animation(.easeOut(duration: 0.4), value: actionsVisible)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .task {
            withAnimation { headerVisible = true }
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation { infoVisible = true }
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation { actionsVisible = true }
        }
        .alert("Xác nhận xoá", isPresented: $showingDeleteConfirm) {
            Button("Xoá", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Bạn có chắc muốn xoá kiểm tra \(inspection.inspectionNumber) không?")
        }
    }

    // MARK: - Drag Indicator

    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color(.systemGray4))
            .frame(width: 36, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Hero Header

    // Gradient adapts: light mode is vivid, dark mode dims slightly to avoid oversaturation
    private var heroGradientColors: [Color] {
        colorScheme == .dark
            ? [LMSColor.primary.opacity(0.82), LMSColor.primary.opacity(0.55)]
            : [LMSColor.primary, LMSColor.primary.opacity(0.72)]
    }

    private var heroShadowOpacity: Double {
        colorScheme == .dark ? 0.18 : 0.35
    }

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: heroGradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle noise overlay for depth in both modes
            Rectangle()
                .fill(
                    colorScheme == .dark
                        ? LMSColor.black.opacity(0.12)
                        : LMSColor.white.opacity(0.06)
                )

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    LMSLabel(
                        inspection.inspectionNumber.isEmpty ? "---" : inspection.inspectionNumber,
                        style: .title3
                    )
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }

                glowBadge(
                    label: inspection.status.displayName,
                    color: .white
                )
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: LMSColor.primary.opacity(heroShadowOpacity), radius: 16, x: 0, y: 6)
    }

    // MARK: - Status Badge with Glow

    private func glowBadge(label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(inspection.status.badgeColor)
                .frame(width: 7, height: 7)

            LMSLabel(label, style: .caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.18))
                .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1))
                .shadow(color: inspection.status.badgeColor.opacity(0.25), radius: 6)
        )
    }

    // MARK: - Info Section

    private var infoSection: some View {
        LMSSectionContainer(title: "Thông tin kiểm tra") {
            VStack(spacing: 8) {
                LMSInfoRow(label: "Công ty", value: inspection.companyName.isEmpty ? "---" : inspection.companyName)
                LMSInfoRow(label: "Sản phẩm", value: inspection.productName.isEmpty ? "---" : inspection.productName)
                LMSInfoRow(label: "Mã sản phẩm", value: inspection.productCode.isEmpty ? "---" : inspection.productCode)
                LMSInfoRow(label: "Nhà máy", value: inspection.factory.isEmpty ? "---" : inspection.factory)
                LMSInfoRow(label: "Ngày tạo", value: inspection.formattedDate)
            }
        }
        // Subtle border gives edge contrast on dark backgrounds
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    colorScheme == .dark
                        ? LMSColor.white.opacity(0.07)
                        : LMSColor.black.opacity(0.04),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Pinned Action Bar

    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            LMSButton("Xoá", icon: "trash", variant: .destructive, action: {
                showingDeleteConfirm = true
            })
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .scaleEffect(deletePressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: deletePressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($deletePressed) { _, state, _ in state = true }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - InspectionStatus + badge color

private extension InspectionStatus {
    var badgeColor: Color {
        switch self {
        case .plan:       return LMSColor.primary
        case .inProgress: return LMSColor.warning
        case .completed:  return LMSColor.success
        case .error:      return LMSColor.destructive
        case .cancelled:  return Color(.systemGray)
        }
    }
}

// MARK: - Preview

private let _previewInspection = Inspection(
    id: "preview",
    inspectionNumber: "INS-2026-020",
    companyName: "Công ty TNHH ABC",
    productName: "Ghế văn phòng",
    productCode: "GVP-001",
    orderCode: "ORD-2026-020",
    inspectionType: "Final Inspection",
    quantity: "500",
    factory: "Nhà máy Hà Nội",
    productionUnit: "Pcs",
    createdAt: Date(),
    status: .completed
)

#Preview("Light mode") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            InspectionDetailBottomSheet(inspection: _previewInspection, onDelete: {})
        }
        .environmentObject(LocalizationManager.shared)
        .preferredColorScheme(.light)
}

#Preview("Dark mode") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            InspectionDetailBottomSheet(inspection: _previewInspection, onDelete: {})
        }
        .environmentObject(LocalizationManager.shared)
        .preferredColorScheme(.dark)
}
