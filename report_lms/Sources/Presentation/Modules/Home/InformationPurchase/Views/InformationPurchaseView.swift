//
//  InformationPurchaseView.swift
//  report_lms
//
//  Created by Hai Phan on 2026-02-07.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

struct InformationPurchaseView: View {
    // MARK: - Properties
    let inspection: Inspection?

    // Animation
    @State private var section1Visible = false
    @State private var section2Visible = false

    // MARK: - Body
    var body: some View {
        ScrollView {
            contentView
        }
        .task {
            withAnimation(.easeOut(duration: 0.4)) { section1Visible = true }
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeOut(duration: 0.4)) { section2Visible = true }
        }
    }

    // MARK: - Private Views
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 20) {
            section1View
                .opacity(section1Visible ? 1 : 0)
                .offset(y: section1Visible ? 0 : 16)

            section2View
                .opacity(section2Visible ? 1 : 0)
                .offset(y: section2Visible ? 0 : 16)
        }
        .padding(16)
    }

    private var section1View: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LMSColor.primary)
                    .frame(width: 3, height: 20)
                LMSLabel(inspection?.productName ?? "—", style: .title)
                    .lineLimit(2)
            }
            Divider()
            infoRow(label: "Đơn đặt hàng:", value: inspection?.orderCode ?? "—")
            infoRow(label: "Mã sản phẩm:", value: inspection?.productCode ?? "—")
            infoRow(label: "Loại kiểm tra:", value: inspection?.inspectionType ?? "—")
        }
        .padding(16)
        .background(cardBackground)
    }

    private var section2View: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LMSColor.primary)
                    .frame(width: 3, height: 20)
                LMSLabel("Thông tin kiểm hàng", style: .headline)
            }
            Divider()
            infoRow(label: "Tên sản phẩm:", value: inspection?.productName ?? "—")
            infoRow(label: "Tổng số lượng:", value: inspection?.quantity ?? "—")
            infoRow(label: "Đơn vị sản xuất:", value: inspection?.productionUnit ?? "—")
            infoRow(label: "Tên nhà máy:", value: inspection?.factory ?? "—")
            infoRow(label: "Ngày tạo đơn:", value: formattedDate)
        }
        .padding(16)
        .background(cardBackground)
    }

    private var formattedDate: String {
        guard let date = inspection?.createdAt else { return "—" }
        let f = DateFormatter()
        f.dateStyle = .long
        f.locale = Locale(identifier: "vi_VN")
        return f.string(from: date)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(UIColor.systemBackground))
            .shadow(color: LMSColor.Shadow.subtle, radius: 6, x: 0, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(LMSColor.Border.subtle, lineWidth: 1)
            )
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            LMSLabel(label, style: .body)
            Spacer()
            LMSLabel(value, style: .body, color: .secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Preview
#Preview("With data") {
    NavigationStack {
        InformationPurchaseView(
            inspection: Inspection(
                id: "1",
                inspectionNumber: "INS-2026-001",
                productName: "Ghế văn phòng",
                productCode: "GVP-001",
                orderCode: "ORD-2026-001",
                inspectionType: "Final Inspection",
                quantity: "500",
                factory: "Nhà máy Hà Nội",
                productionUnit: "Pcs",
                status: .completed
            )
        )
    }
}

#Preview("Loading / nil") {
    NavigationStack {
        InformationPurchaseView(inspection: nil)
    }
}
