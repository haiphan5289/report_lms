//
//  InspectionSectionView.swift
//  report_lms
//
//  Created by GitHub Copilot on 1/2/26.
//

import SwiftUI

/// Collapsible section for inspection forms with green chevron indicator
struct InspectionSectionView: View {
    // MARK: - Properties
    let title: String
    let itemCount: Int
    let isExpanded: Bool
    let onToggle: () -> Void
    let content: () -> AnyView
    
    // MARK: - Initialization
    init(
        title: String,
        itemCount: Int,
        isExpanded: Bool,
        onToggle: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> some View
    ) {
        self.title = title
        self.itemCount = itemCount
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.content = { AnyView(content()) }
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            if isExpanded {
                contentView
            }
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Private Views
    private var headerView: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                onToggle()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.green)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    .animation(.easeInOut(duration: 0.3), value: isExpanded)
                
                LMSLabel(
                    "\(title) (\(itemCount))",
                    style: .body
                )
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var contentView: some View {
        VStack(spacing: 0) {
            content()
        }
    }
}

// MARK: - Preview
#Preview("Collapsed") {
    InspectionSectionView(
        title: "Ngoài thùng carton",
        itemCount: 2,
        isExpanded: false,
        onToggle: {}
    ) {
        VStack(spacing: 1) {
            InspectionFieldItemView(
                fieldName: "Tổng quan về thùng carton",
                hasPhoto: false,
                onCameraTap: {}
            )
            
            Divider()
            
            InspectionFieldItemView(
                fieldName: "Thông tin in trên thùng carton",
                hasPhoto: false,
                onCameraTap: {}
            )
        }
    }
    .padding()
}

#Preview("Expanded") {
    InspectionSectionView(
        title: "Ngoài thùng carton",
        itemCount: 2,
        isExpanded: true,
        onToggle: {}
    ) {
        VStack(spacing: 1) {
            InspectionFieldItemView(
                fieldName: "Tổng quan về thùng carton",
                hasPhoto: false,
                onCameraTap: {}
            )
            
            Divider()
            
            InspectionFieldItemView(
                fieldName: "Thông tin in trên thùng carton",
                hasPhoto: true,
                onCameraTap: {}
            )
        }
    }
    .padding()
}

#Preview("Multiple Sections") {
    ScrollView {
        VStack(spacing: 12) {
            InspectionSectionView(
                title: "Ngoài thùng carton",
                itemCount: 2,
                isExpanded: true,
                onToggle: {}
            ) {
                VStack(spacing: 1) {
                    InspectionFieldItemView(
                        fieldName: "Tổng quan về thùng carton",
                        hasPhoto: false,
                        onCameraTap: {}
                    )
                    
                    Divider()
                    
                    InspectionFieldItemView(
                        fieldName: "Thông tin in trên thùng carton",
                        hasPhoto: false,
                        onCameraTap: {}
                    )
                }
            }
            
            InspectionSectionView(
                title: "Trong thùng carton",
                itemCount: 2,
                isExpanded: false,
                onToggle: {}
            ) {
                EmptyView()
            }
            
            InspectionSectionView(
                title: "Tổng quan về sản phẩm",
                itemCount: 8,
                isExpanded: false,
                onToggle: {}
            ) {
                EmptyView()
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
