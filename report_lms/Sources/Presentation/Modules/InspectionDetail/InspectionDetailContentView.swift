//
//  InspectionDetailContentView.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/3/26.
//

import SwiftUI

struct InspectionDetailContentView: View {
    // MARK: - Constants
    private enum Layout {
        static let sectionSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 16
        static let errorIconSize: CGFloat = 48
        static let errorSpacing: CGFloat = 16
        static let retryButtonMaxWidth: CGFloat = 200
        static let retryButtonHeight: CGFloat = 44
    }
    
    // MARK: - Properties
    @ObservedObject var contentViewModel: InspectionDetailContentViewModel
    let onRetry: () async -> Void
    let errorMessage: String?
    
    @State private var showAddCustomField = false
    
    // MARK: - Body
    var body: some View {
        Group {
            if let detail = contentViewModel.inspectionDetail {
                sectionListView(detail: detail)
            } else if let errorMessage = errorMessage {
                errorView(message: errorMessage)
            } else {
                EmptyView()
            }
        }
    }
    
    // MARK: - Private Views
    private func sectionListView(detail: InspectionDetail) -> some View {
        ScrollView {
            LazyVStack(spacing: Layout.sectionSpacing) {
                // Existing inspection sections
                ForEach(detail.sections.sorted(by: { $0.order < $1.order })) { section in
                    sectionView(for: section)
                }
                
                // Button: Thêm điểm kiểm tra
                addCustomFieldButton()
                
                // Button: Tóm tắt và gửi
                summaryButton()
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $showAddCustomField) {
            AddCustomFieldView { label, type in
                // Handle custom field creation
                print("Custom field: \(label), type: \(type)")
                // TODO: Add logic to create custom field
            }
        }
    }

    private func sectionView(for section: InspectionSection) -> some View {
        InspectionSectionView(
            title: section.title,
            itemCount: section.itemCount,
            isExpanded: contentViewModel.isExpanded(section.id),
            onToggle: { contentViewModel.toggleSection(section.id) },
            content: {
                fieldListView(for: section.fields)
            }
        )
    }

    private func fieldListView(for fields: [InspectionField]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
                fieldItemView(for: field)

                if index < fields.count - 1 {
                    Divider()
                        .padding(.leading, Layout.horizontalPadding)
                }
            }
        }
    }

    private func fieldItemView(for field: InspectionField) -> some View {
        InspectionFieldItemView(
            fieldName: field.label,
            hasPhoto: contentViewModel.hasPhoto(for: field.id),
            images: contentViewModel.getImages(for: field.id),
            onCameraTap: { contentViewModel.openPhotoPicker(for: field.id) }
        )
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: Layout.errorSpacing) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: Layout.errorIconSize))
                .foregroundColor(.red)

            LMSLabel(message, style: .body, alignment: .center)

            retryButton
        }
        .padding()
    }

    private var retryButton: some View {
        LMSButton("Thử lại", icon: "arrow.clockwise", variant: .primary, action: {
            Task {
                await onRetry()
            }
        })
        .frame(maxWidth: Layout.retryButtonMaxWidth)
        .frame(height: Layout.retryButtonHeight)
    }
    
    // MARK: - New Action Buttons
    
    private func addCustomFieldButton() -> some View {
        LMSButton(
            "Thêm điểm kiểm tra",
            icon: "plus.circle.fill",
            variant: .ghost,
            action: {
                showAddCustomField = true
            }
        )
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func summaryButton() -> some View {
        VStack(spacing: 8) {
            LMSButton(
                "Tóm tắt và gửi",
                icon: "paperplane.fill",
                variant: .primary,
                action: {
                    // TODO: Handle submit action
                    print("Submit inspection")
                }
            )
            .frame(height: 50)
        }
    }
}

// MARK: - Preview
private struct PreviewWrapper: View {
    @StateObject private var parentViewModel: InspectionDetailViewModel
    let errorMessage: String?
    
    init(parentViewModel: InspectionDetailViewModel, errorMessage: String?) {
        _parentViewModel = StateObject(wrappedValue: parentViewModel)
        self.errorMessage = errorMessage
    }
    
    var body: some View {
        InspectionDetailContentView(
            contentViewModel: parentViewModel.contentViewModel,
            onRetry: {},
            errorMessage: errorMessage
        )
    }
}

#Preview("With Data") {
    PreviewWrapper(
        parentViewModel: InspectionDetailViewModel.previewWithData(),
        errorMessage: nil
    )
}

#Preview("With Error") {
    PreviewWrapper(
        parentViewModel: InspectionDetailViewModel.previewWithError(),
        errorMessage: "Không thể tải dữ liệu. Vui lòng kiểm tra kết nối mạng."
    )
}

#Preview("Empty State") {
    PreviewWrapper(
        parentViewModel: InspectionDetailViewModel(
            inspectionId: "1",
            inspectionNumber: "001"
        ),
        errorMessage: nil
    )
}
