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
        
        // Action Button Styling
        static let actionButtonHeight: CGFloat = 56
        static let actionButtonCornerRadius: CGFloat = 12
        static let actionButtonBorderWidth: CGFloat = 1.5
        static let actionButtonSpacing: CGFloat = 16
        static let actionButtonIconSize: CGFloat = 20
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
        .sheet(isPresented: $contentViewModel.isShowingMailComposer) {
            if let pdfData = contentViewModel.pdfData {
                MailComposerView(
                    pdfData: pdfData,
                    inspectionNumber: contentViewModel.inspectionDetail?.inspectionNumber ?? ""
                )
            }
        }
        .sheet(isPresented: $contentViewModel.isShowingPDFPreview) {
            if let pdfData = contentViewModel.pdfData {
                PDFPreviewView(
                    pdfData: pdfData,
                    fileName: "Bao_cao_kiem_tra_\(contentViewModel.inspectionDetail?.inspectionNumber ?? "").pdf"
                )
            }
        }
        .overlay {
            if contentViewModel.isGeneratingPDF {
                LoadingOverlayView(message: "Đang tạo PDF...")
            }
        }
        .alert("Lỗi tạo PDF", isPresented: .constant(contentViewModel.pdfError != nil)) {
            Button("OK") {
                contentViewModel.resetPDFState()
            }
        } message: {
            if let error = contentViewModel.pdfError {
                Text(error)
            }
        }
        .alert("Email không khả dụng", isPresented: $contentViewModel.showMailUnavailableAlert) {
            Button("OK") { }
        } message: {
            Text("Thiết bị này chưa được cấu hình email. Vui lòng thiết lập tài khoản email trong Cài đặt.")
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
                
                // Action Buttons
                HStack(spacing: 12) {
                    // Preview PDF button
                    previewPDFButton()
                    
                    // Send Email button
                    sendEmailButton()
                }
                .padding(.top, 8)
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
        Button(action: {
            showAddCustomField = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: Layout.actionButtonIconSize, weight: .medium))
                    .foregroundColor(LMSColor.primary)
                
                Text("Thêm điểm kiểm tra")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(LMSColor.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Layout.actionButtonHeight)
            .background(LMSColor.white)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.actionButtonCornerRadius)
                    .stroke(LMSColor.primaryBorder, lineWidth: Layout.actionButtonBorderWidth)
            )
            .cornerRadius(Layout.actionButtonCornerRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Thêm điểm kiểm tra tùy chỉnh")
        .accessibilityHint("Thêm một điểm kiểm tra mới vào danh sách")
    }
    
    private func previewPDFButton() -> some View {
        Button(action: {
            Task {
                await contentViewModel.generateAndPreviewPDF()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: Layout.actionButtonIconSize, weight: .medium))
                    .foregroundColor(LMSColor.primary)
                
                Text("Xem PDF")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(LMSColor.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Layout.actionButtonHeight)
            .background(LMSColor.white)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.actionButtonCornerRadius)
                    .stroke(LMSColor.primaryBorder, lineWidth: Layout.actionButtonBorderWidth)
            )
            .cornerRadius(Layout.actionButtonCornerRadius)
        }
        .buttonStyle(.plain)
        .disabled(contentViewModel.isGeneratingPDF)
        .opacity(contentViewModel.isGeneratingPDF ? 0.6 : 1.0)
        .accessibilityLabel("Xem trước PDF")
        .accessibilityHint("Tạo và xem trước file PDF trước khi gửi")
    }
    
    private func sendEmailButton() -> some View {
        Button(action: {
            Task {
                await contentViewModel.generateAndSendPDF()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: Layout.actionButtonIconSize, weight: .medium))
                    .foregroundColor(LMSColor.white)
                
                Text("Gửi Email")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(LMSColor.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Layout.actionButtonHeight)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [LMSColor.primary, LMSColor.primary.opacity(0.85)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(Layout.actionButtonCornerRadius)
            .shadow(color: LMSColor.primary.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(contentViewModel.isGeneratingPDF)
        .opacity(contentViewModel.isGeneratingPDF ? 0.6 : 1.0)
        .accessibilityLabel("Gửi báo cáo qua Email")
        .accessibilityHint("Tạo file PDF và gửi qua email")
    }
}

// MARK: - Loading Overlay
private struct LoadingOverlayView: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
            )
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
