//
//  LMSSectionContainer.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/6/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

/// A reusable container component for consistent section styling
/// Provides standardized padding, background, and optional header
struct LMSSectionContainer<Content: View>: View {
    // MARK: - Properties
    let title: String?
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let padding: CGFloat
    let content: () -> Content
    
    // Layout constants (inline - can't use static stored properties in generic types)
    private let headerSpacing: CGFloat = 12
    
    // MARK: - Initialization
    init(
        title: String? = nil,
        backgroundColor: Color = Color(.systemBackground),
        cornerRadius: CGFloat = 12,
        padding: CGFloat = 16,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: headerSpacing) {
            if let title = title {
                LMSLabel(title, style: .headline)
            }
            
            content()
        }
        .padding(padding)
        .background(backgroundColor)
        .cornerRadius(cornerRadius)
    }
}

// MARK: - Preview
#Preview("With Title") {
    LMSSectionContainer(title: "Thông tin cơ bản") {
        VStack(spacing: 8) {
            LMSInfoRow(label: "Tên", value: "Sản phẩm A")
            LMSInfoRow(label: "Mã", value: "SP001")
            LMSInfoRow(label: "Số lượng", value: "100")
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Without Title") {
    LMSSectionContainer {
        VStack(spacing: 12) {
            Text("Nội dung bên trong section")
                .font(.body)
            
            Button("Thao tác") {
                // Action
            }
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Custom Styling") {
    LMSSectionContainer(
        title: "Cảnh báo",
        backgroundColor: LMSColor.secondaryBackground,
        cornerRadius: 8,
        padding: 12
    ) {
        Text("Đã vượt quá giới hạn cho phép")
            .font(.callout)
            .foregroundColor(LMSColor.destructive)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Multiple Sections") {
    ScrollView {
        VStack(spacing: 16) {
            LMSSectionContainer(title: "Số lượng") {
                VStack(spacing: 8) {
                    LMSInfoRow(label: "Đơn hàng", value: "1000")
                    LMSInfoRow(label: "Đã kiểm tra", value: "250")
                }
            }
            
            LMSSectionContainer(title: "Vị trí") {
                TextField("Nhập vị trí", text: .constant(""))
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            LMSSectionContainer(title: "Ghi chú") {
                TextEditor(text: .constant(""))
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
