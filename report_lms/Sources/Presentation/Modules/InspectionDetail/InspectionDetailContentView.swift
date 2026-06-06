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
    let onErrorSaved: (SavedErrorItem, [UIImage]) -> Void
    let hasActiveUploads: Bool
    let activeUploadCount: Int
    let onCompleteInspection: () -> Void
    let onShowUploadStatus: () -> Void

    @State private var showAddCustomField = false
    @State private var showErrorCamera = false
    @State private var capturedErrorImages: [UIImage] = []
    @State private var showErrorReview = false
    @State private var inspectionIdSnapshot: String? = nil
    @GestureState private var addFieldPressed = false
    @GestureState private var completePressed = false

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
        .fullScreenCover(isPresented: $showErrorCamera) {
            CameraView(source: .errorReport) { images in
                capturedErrorImages = images
                inspectionIdSnapshot = contentViewModel.inspection?.id
            }
        }
        .onChange(of: showErrorCamera) { _, isShowing in
            if !isShowing && !capturedErrorImages.isEmpty {
                showErrorReview = true
            }
        }
        .sheet(isPresented: $showErrorReview, onDismiss: {
            capturedErrorImages = []
            inspectionIdSnapshot = nil
        }) {
            if let inspectionId = inspectionIdSnapshot {
                NavigationStack {
                    PhotoCaptureErrorReviewView(
                        inspectionId: inspectionId,
                        initialImages: capturedErrorImages.map { ImageWithNote(source: .local(image: $0)) },
                        onImagesUpdated: { _ in },
                        onSaved: { saved, images in
                            onErrorSaved(saved, images)
                            onSwitchToErrorTab()
                        }
                    )
                }
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
    }

    private func sectionView(for section: InspectionSection) -> some View {
        InspectionSectionView(
            title: section.localizedTitle(using: localizationManager),
            itemCount: section.itemCount,
            completedCount: contentViewModel.completedCount(for: section),
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
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 0) {
                        HStack {
                            LMSSkeleton().frame(width: 120, height: 14).clipShape(Capsule())
                            Spacer()
                            LMSSkeleton().frame(width: 40, height: 14).clipShape(Capsule())
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(UIColor.systemBackground))
                                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                        )
                        VStack(spacing: 0) {
                            LMSInspectionCardSkeleton()
                            LMSInspectionCardSkeleton()
                        }
                    }
                }
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
        .shadow(color: Color.orange.opacity(0.45), radius: 14, x: 0, y: 6)
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
        .scaleEffect(addFieldPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: addFieldPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($addFieldPressed) { _, state, _ in state = true }
        )
        .accessibilityLabel("Thêm điểm kiểm tra tùy chỉnh")
        .accessibilityHint("Thêm một điểm kiểm tra mới vào danh sách")
    }

    private func completeInspectionButton() -> some View {
        ZStack {
            // Base button — "Hoàn tất" or dimmed waiting state
            Button(action: { onCompleteInspection() }) {
                HStack(spacing: 12) {
                    if hasActiveUploads {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: LMSColor.white))
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: Layout.actionButtonIconSize, weight: .medium))
                            .foregroundColor(LMSColor.white)
                    }

                    Text(hasActiveUploads
                         ? "Đang tải ảnh (\(activeUploadCount))..."
                         : localizationManager.localize("inspection.button.complete"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LMSColor.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: Layout.actionButtonHeight)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            hasActiveUploads ? LMSColor.primary.opacity(0.6) : LMSColor.primary,
                            hasActiveUploads ? LMSColor.primary.opacity(0.5) : LMSColor.primary.opacity(0.85)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(Layout.actionButtonCornerRadius)
                .shadow(color: LMSColor.primary.opacity(0.25), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .scaleEffect(completePressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: completePressed)
            .animation(.easeInOut(duration: 0.25), value: hasActiveUploads)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($completePressed) { _, state, _ in state = true }
            )

            // Tap-anywhere-on-button overlay when uploading → open status sheet
            if hasActiveUploads {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { onShowUploadStatus() }
            }
        }
        .frame(height: Layout.actionButtonHeight)
        .padding(.top, 8)
        .accessibilityLabel(hasActiveUploads ? "Đang tải ảnh lên — nhấn để xem chi tiết" : "Hoàn tất kiểm tra")
        .accessibilityHint(hasActiveUploads ? "Mở trạng thái tải ảnh" : "Mở màn hình hoàn tất kiểm tra và gửi báo cáo")
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
            onSwitchToErrorTab: {},
            onErrorSaved: { _, _ in },
            hasActiveUploads: false,
            activeUploadCount: 0,
            onCompleteInspection: {},
            onShowUploadStatus: {}
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
