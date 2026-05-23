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
    @StateObject private var viewModel = InformationPurchaseViewModel()

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
            // Accent header
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LMSColor.primary)
                    .frame(width: 3, height: 20)
                LMSLabel(viewModel.productName, style: .title)
            }
            Divider()
            infoRow(label: "Đơn đặt hàng:", value: viewModel.orderNumber)
            infoRow(label: "Sản phẩm:", value: viewModel.productCode)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: LMSColor.Shadow.subtle, radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LMSColor.Border.subtle, lineWidth: 1)
                )
        )
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
            infoRow(label: "Tên sản phẩm:", value: viewModel.productName)
            infoRow(label: "Tổng số lượng:", value: viewModel.totalQuantity)
            infoRow(label: "Số lượng mẫu cần kiếm:", value: viewModel.sampleQuantity)
            HStack {
                LMSLabel("Số lượng thùng cần kiếm:", style: .body)
                Spacer()
                LMSLabel(viewModel.boxQuantity, style: .body, color: .custom(.green))
            }
            infoRow(label: "Tên nhà máy:", value: viewModel.factoryName)
            infoRow(label: "Ngày dự kiến kiểm hàng:", value: viewModel.inspectionDate)
            infoRow(label: "Nhà máy:", value: viewModel.factoryLocation)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: LMSColor.Shadow.subtle, radius: 6, x: 0, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LMSColor.Border.subtle, lineWidth: 1)
                )
        )
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            LMSLabel(label, style: .body)
            Spacer()
            LMSLabel(value, style: .body, color: .secondary)
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        InformationPurchaseView()
    }
}
