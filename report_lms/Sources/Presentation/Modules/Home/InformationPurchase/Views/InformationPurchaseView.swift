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
    
    // MARK: - Body
    var body: some View {
        ScrollView {
            contentView
        }
    }
    
    // MARK: - Private Views
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 32) {
            section1View
            section2View
        }
        .padding()
    }
    
    private var section1View: some View {
        VStack(alignment: .leading, spacing: 16) {
            LMSLabel(viewModel.productName, style: .title)
            HStack {
                LMSLabel("Đơn đặt hàng:", style: .body)
                Spacer()
                LMSLabel(viewModel.orderNumber, style: .body)
            }
            HStack {
                LMSLabel("Sản phẩm:", style: .body)
                Spacer()
                LMSLabel(viewModel.productCode, style: .body)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var section2View: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                LMSLabel("Tên sản phẩm:", style: .body)
                Spacer()
                LMSLabel(viewModel.productName, style: .body)
            }
            HStack {
                LMSLabel("Tổng số lượng", style: .body)
                Spacer()
                LMSLabel(viewModel.totalQuantity, style: .body)
            }
            HStack {
                LMSLabel("Số lượng mẫu cần kiếm", style: .body)
                Spacer()
                LMSLabel(viewModel.sampleQuantity, style: .body)
            }
            HStack {
                LMSLabel("Số lượng thùng cần kiếm", style: .body)
                Spacer()
                Text(viewModel.boxQuantity)
                    .foregroundColor(.green)
            }
            HStack {
                LMSLabel("Tên nhà máy", style: .body)
                Spacer()
                LMSLabel(viewModel.factoryName, style: .body)
            }
            HStack {
                LMSLabel("Ngày dự kiến kiểm hàng:", style: .body)
                Spacer()
                LMSLabel(viewModel.inspectionDate, style: .body)
            }
            HStack {
                LMSLabel("Nhà máy", style: .body)
                Spacer()
                LMSLabel(viewModel.factoryLocation, style: .body)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        InformationPurchaseView()
    }
}
