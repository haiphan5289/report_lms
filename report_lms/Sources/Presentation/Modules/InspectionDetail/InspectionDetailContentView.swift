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
    @EnvironmentObject private var localizationManager: LocalizationManager
    let onRetry: () async -> Void
    let errorMessage: String?
    let onSwitchToErrorTab: () -> Void

    @State private var showAddCustomField = false
    @State private var showFinalReport = false
    @State private var showErrorCamera = false
    @State private var capturedErrorImages: [UIImage] = []
    @State private var showErrorReview = false

    // MARK: - Body
    var body: some View {
        Group {
            if contentViewModel.inspection != nil {
                ZStack(alignment: .bottomTrailing) {
                    sectionListView()
                    floatingButton
                }
            } else if let errorMessage = errorMessage {
                errorView(message: errorMessage)
            } else {
                loadingPlaceholder
            }
        }
        .navigationDestination(isPresented: $showErrorCamera) {
            CameraView(source: .errorReport) { images in
                capturedErrorImages = images
                showErrorReview = true
            }
        }
        .sheet(isPresented: $showErrorReview) {
            if let inspectionId = contentViewModel.inspection?.id {
                PhotoCaptureErrorReviewView(
                    inspectionId: inspectionId,
                    initialImages: capturedErrorImages.map { .local(image: $0) },
                    onImagesUpdated: { _ in },
                    onSaved: { _, _ in
                        onSwitchToErrorTab()
                    }
                )
            }
        }
    }
    
    // MARK: - Private Views
    private func sectionListView() -> some View {
        ScrollView {
            LazyVStack(spacing: Layout.sectionSpacing) {
                // Existing inspection sections
                ForEach(contentViewModel.sortedSections) { section in
                    sectionView(for: section)
                }
                
                // Button: Thêm điểm kiểm tra
                addCustomFieldButton()
                
                // Action Button: Hoàn tất kiểm tra
                completeInspectionButton()
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
        .fullScreenCover(isPresented: $showFinalReport) {
            if let detail = contentViewModel.inspection {
                FinalReportView(
                    inspection: detail,
                    capturedPhotos: contentViewModel.capturedPhotos
                )
            }
        }
    }

    private func sectionView(for section: InspectionSection) -> some View {
        InspectionSectionView(
            title: section.localizedTitle(using: localizationManager),
            itemCount: section.itemCount,
            isExpanded: contentViewModel.isExpanded(section.id),
            onToggle: { contentViewModel.toggleSection(section.id) },
            content: {
                fieldListView(for: section.fields)
            }
        )
    }

    private func fieldListView(for fields: [InspectionField]) -> some View {
        LazyVStack(spacing: 0) {
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
            fieldName: field.localizedLabel(using: localizationManager),
            hasPhoto: contentViewModel.hasPhoto(for: field.id),
            images: contentViewModel.getImages(for: field.id),
            onTextTap: { contentViewModel.openValidationView(for: field.id) },
            onCameraTap: { contentViewModel.openCamera(for: field.id) }
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
        LMSButton(localizationManager.localize("common.retry"), icon: "arrow.clockwise", variant: .primary, action: {
            Task {
                await onRetry()
            }
        })
        .frame(maxWidth: Layout.retryButtonMaxWidth)
        .frame(height: Layout.retryButtonHeight)
    }
    
    private var loadingPlaceholder: some View {
        ScrollView {
            VStack {
                // Empty placeholder to maintain layout
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Floating Button

    private var floatingButton: some View {
        Button(action: { showErrorCamera = true }) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: 56, height: 56)
        .background(Circle().fill(Color.orange))
        .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
        .padding(.trailing, 24)
        .padding(.bottom, 24)
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
                
                Text(localizationManager.localize("inspection.button.addField"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(LMSColor.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Layout.actionButtonHeight)
            .background(Color(.systemBackground))
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
    
    private func completeInspectionButton() -> some View {
        Button(action: {
            showFinalReport = true
        }) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: Layout.actionButtonIconSize, weight: .medium))
                    .foregroundColor(LMSColor.white)
                
                Text(localizationManager.localize("inspection.button.complete"))
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
        .padding(.top, 8)
        .accessibilityLabel("Hoàn tất kiểm tra")
        .accessibilityHint("Mở màn hình hoàn tất kiểm tra và gửi báo cáo")
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
            errorMessage: errorMessage,
            onSwitchToErrorTab: {}
        )
    }
}

#Preview("With Data") {
    PreviewWrapper(
        parentViewModel: InspectionDetailViewModel.previewWithData(),
        errorMessage: nil
    )
    .environmentObject(LocalizationManager.shared)
}

#Preview("With Error") {
    PreviewWrapper(
        parentViewModel: InspectionDetailViewModel.previewWithError(),
        errorMessage: "Không thể tải dữ liệu. Vui lòng kiểm tra kết nối mạng."
    )
    .environmentObject(LocalizationManager.shared)
}

#Preview("Empty State") {
    PreviewWrapper(
        parentViewModel: InspectionDetailViewModel(
            inspectionId: "1",
            inspectionNumber: "001"
        ),
        errorMessage: nil
    )
    .environmentObject(LocalizationManager.shared)
}
