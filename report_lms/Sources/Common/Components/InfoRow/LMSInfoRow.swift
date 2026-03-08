//
//  LMSInfoRow.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/6/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

/// A reusable row component displaying label-value pairs
/// Used for displaying structured information in forms and detail views
struct LMSInfoRow: View {
    // MARK: - Constants
    private enum Layout {
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 8
        static let cornerRadius: CGFloat = 8
        static let spacing: CGFloat = 12
    }
    
    // MARK: - Properties
    let label: String
    let value: String
    let labelStyle: LMSTextStyle
    let valueStyle: LMSTextStyle
    let backgroundColor: Color
    
    // MARK: - Initialization
    init(
        label: String,
        value: String,
        labelStyle: LMSTextStyle = .body,
        valueStyle: LMSTextStyle = .body,
        backgroundColor: Color = Color(.systemGray6)
    ) {
        self.label = label
        self.value = value
        self.labelStyle = labelStyle
        self.valueStyle = valueStyle
        self.backgroundColor = backgroundColor
    }
    
    // MARK: - Body
    var body: some View {
        HStack(alignment: .top, spacing: Layout.spacing) {
            LMSLabel(label, style: labelStyle, color: .secondary)
            
            Spacer()
            
            LMSLabel(value, style: valueStyle, color: .primary)
                .fontWeight(.medium)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .background(backgroundColor)
        .cornerRadius(Layout.cornerRadius)
    }
}

// MARK: - Preview
#Preview("Default") {
    VStack(spacing: 8) {
        LMSInfoRow(
            label: "Số lượng đơn hàng",
            value: "1000"
        )
        
        LMSInfoRow(
            label: "Số lượng đã kiểm tra",
            value: "250"
        )
    }
    .padding()
}

#Preview("Custom Styles") {
    VStack(spacing: 8) {
        LMSInfoRow(
            label: "Tổng cộng",
            value: "$1,234.56",
            labelStyle: .headline,
            valueStyle: .title3
        )
        
        LMSInfoRow(
            label: "Trạng thái",
            value: "Hoàn thành",
            backgroundColor: LMSColor.primaryLight
        )
    }
    .padding()
}

#Preview("In Card") {
    VStack(alignment: .leading, spacing: 12) {
        LMSLabel("Thông tin sản phẩm", style: .headline)
        
        VStack(spacing: 8) {
            LMSInfoRow(label: "Mã sản phẩm", value: "SP001")
            LMSInfoRow(label: "Số lượng", value: "100")
            LMSInfoRow(label: "Đơn giá", value: "$50.00")
        }
    }
    .padding()
    .background(Color.white)
    .cornerRadius(12)
    .padding()
}
