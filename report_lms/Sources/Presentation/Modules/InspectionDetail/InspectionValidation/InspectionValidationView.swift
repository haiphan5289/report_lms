//
//  InspectionValidationView.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 1/3/26.
//

import SwiftUI

struct InspectionValidationView: View {
    // MARK: - Constants
    private enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 16
        static let iconSize: CGFloat = 24
        static let imageGridSpacing: CGFloat = 12
        static let imageSize: CGFloat = 100
        static let bottomButtonHeight: CGFloat = 100
        static let buttonIconSize: CGFloat = 40
        static let cornerRadius: CGFloat = 12
    }
    
    // MARK: - Properties
    @StateObject private var viewModel: InspectionValidationViewModel
    @Environment(\.dismiss) private var dismiss

    // Animation
    @State private var contentVisible = false
    @GestureState private var passPressed = false
    @GestureState private var naPressed = false

    // Image actions
    @State private var selectedImageIndex: Int?
    @State private var showImageMenu = false
    @State private var showImageEditor = false
    @State private var editingUIImage: UIImage?
    @State private var sharingImage: UIImage?
    @State private var showShareSheet = false
    @State private var imageRefreshTrigger: Int = 0

    #if DEBUG
    @State private var showCacheDebug = false
    #endif

    // Inspection context stored for gallery + debug panel
    private let inspectionIdContext: String?
    private let fieldIdContext: String
    
    // MARK: - Initialization
    init(
        fieldId: String,
        fieldLabel: String,
        initialImages: [InspectionImage],
        inspectionId: String? = nil,
        onSave: @escaping (FieldValidation) -> Void,
        onUploadComplete: (() -> Void)? = nil,
        onTaskCompleted: (() -> Void)? = nil,
        onImageProgress: (@Sendable (Int, Double) -> Void)? = nil,
        onImageDone: (@Sendable (Int) -> Void)? = nil,
        onImageFail: (@Sendable (Int) -> Void)? = nil
    ) {
        self.inspectionIdContext = inspectionId
        self.fieldIdContext = fieldId
        _viewModel = StateObject(
            wrappedValue: InspectionValidationViewModel(
                fieldId: fieldId,
                fieldLabel: fieldLabel,
                initialImages: initialImages,
                inspectionId: inspectionId,
                onSave: onSave,
                onUploadComplete: onUploadComplete,
                onTaskCompleted: onTaskCompleted,
                onImageProgress: onImageProgress,
                onImageDone: onImageDone,
                onImageFail: onImageFail
            )
        )
    }
    
    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: Layout.sectionSpacing) {
                    headerSection
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 16)
                        .animation(.easeOut(duration: 0.35), value: contentVisible)
                    statusSection
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 16)
                        .animation(.easeOut(duration: 0.35).delay(0.08), value: contentVisible)
                    if viewModel.hasImages {
                        imageGallerySection
                            .opacity(contentVisible ? 1 : 0)
                            .offset(y: contentVisible ? 0 : 16)
                            .animation(.easeOut(duration: 0.35).delay(0.16), value: contentVisible)
                    }
                    actionsSection
                        .opacity(contentVisible ? 1 : 0)
                        .offset(y: contentVisible ? 0 : 16)
                        .animation(.easeOut(duration: 0.35).delay(0.24), value: contentVisible)
                    Spacer()
                        .frame(height: Layout.bottomButtonHeight + 20)
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, Layout.horizontalPadding)
            }
            .background(Color(.systemGroupedBackground))
            .contentShape(Rectangle())
            .onTapGesture {
                hideKeyboard()
            }
            // Fixed bottom buttons
            bottomActionsView
            // Upload progress toast — floats above bottom buttons
            if viewModel.isUploading {
                uploadToastView
                    .padding(.bottom, Layout.bottomButtonHeight + 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.isUploading)
        .navigationTitle(viewModel.fieldLabel)
        .navigationBarTitleDisplayMode(.inline)
//        #if DEBUG
//        .toolbar {
//            ToolbarItem(placement: .navigationBarTrailing) {
//                CacheDebugButton(isPresented: $showCacheDebug)
//            }
//        }
//        .sheet(isPresented: $showCacheDebug) {
//            CacheDebugOverlay(
//                inspectionId: inspectionIdContext ?? "unknown",
//                fieldId: fieldIdContext
//            )
//            .presentationDetents([.medium, .large])
//            .presentationDragIndicator(.visible)
//        }
//        #endif
        .task {
            withAnimation(.easeOut(duration: 0.35)) { contentVisible = true }
            await viewModel.loadPendingCaptures()
        }
        .sheet(isPresented: $viewModel.showCamera) {
            CameraView(source: .inspection) { images in
                viewModel.appendImages(images)
            }
            .environmentObject(LocalizationManager.shared)
        }
        .confirmationDialog("", isPresented: $showImageMenu) {
            Button("Chỉnh sửa") { Task { await handleEditImage() } }
            Button("Chia sẻ") { Task { await handleShareImage() } }
            Button("Xoá bỏ", role: .destructive) {
                if let index = selectedImageIndex {
                    viewModel.requestDeleteImage(at: index)
                }
            }
            Button("Huỷ", role: .cancel) {}
        }
        .sheet(isPresented: $showImageEditor) {
            if let image = editingUIImage, let index = selectedImageIndex {
                ImageEditorView(image: image) { editedImage in
                    viewModel.replaceImage(at: index, with: editedImage)
                    imageRefreshTrigger += 1
                }
                .environmentObject(LocalizationManager.shared)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = sharingImage {
                ShareSheet(items: [image])
            }
        }
        .overlay {
            if viewModel.isDownloading {
                LMSLoadingOverlay()
            }
        }
        .lmsSnackbar(message: $viewModel.snackbarMessage, type: .error)
        .fullScreenCover(isPresented: $viewModel.showDeleteConfirmation) {
            DeleteConfirmationView(
                title: "Xóa ảnh",
                message: "Bạn có chắc chắn muốn xóa ảnh này không?",
                confirmTitle: "Xóa"
            ) {
                viewModel.confirmDeleteImage()
            }
            .background(ClearBackgroundView())
        }
    }

    // MARK: - Keyboard Dismiss Helper
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    // MARK: - Section Views
    
    private var headerSection: some View {
        HStack {
            Text(viewModel.fieldLabel)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                viewModel.openCamera()
            }) {
                Image(systemName: "camera.fill")
                    .font(.system(size: Layout.iconSize))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(LMSColor.primary)
                    .clipShape(Circle())
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(Layout.cornerRadius)
        .shadow(color: LMSColor.shadow, radius: 2, x: 0, y: 1)
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text(viewModel.fieldLabel)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Divider()
            
            // Status (Trạng thái)
            VStack(alignment: .leading, spacing: 8) {
                Text("Trạng thái")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Tình trạng hiện tại")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(viewModel.status.displayText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(statusColor(for: viewModel.status))
                }
            }
            
            Divider()
            
            // Comments (Nhận xét)
            VStack(alignment: .leading, spacing: 8) {
                Text("Nhận xét")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextEditor(text: Binding(
                    get: { viewModel.comments },
                    set: { viewModel.updateComments($0) }
                ))
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if viewModel.comments.isEmpty {
                        Text("Viết nhận xét tại đây")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(Layout.cornerRadius)
        .shadow(color: LMSColor.shadow, radius: 2, x: 0, y: 1)
    }
    
    private var imageGallerySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                LMSLabel("Thư viện phương tiện truyền thông", style: .headline)
                Spacer()
                LMSLabel("\(viewModel.images.count) ảnh", style: .caption, color: .secondary)
            }
            if viewModel.images.isEmpty {
                LMSLabel("Chưa có ảnh nào", style: .body, color: .secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 16) {
                    ForEach($viewModel.images) { $image in
                        ImageGalleryItemView(
                            inspectionImage: image,
                            isReorderMode: viewModel.showReorderMode,
                            onDelete: {
                                if let index = viewModel.images.firstIndex(where: { $0.id == image.id }) {
                                    viewModel.requestDeleteImage(at: index)
                                }
                            },
                            onMenu: {
                                selectedImageIndex = viewModel.images.firstIndex(where: { $0.id == image.id })
                                showImageMenu = true
                            },
                            descriptionBinding: $image.description,
                            inspectionId: inspectionIdContext,
                            fieldId: fieldIdContext
                        )
                        .id("\(image.id)-\(imageRefreshTrigger)")
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(Layout.cornerRadius)
        .shadow(color: LMSColor.shadow, radius: 2, x: 0, y: 1)
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Add more photos button
            LMSButton(
                "Chụp thêm ảnh",
                icon: "camera.fill",
                variant: .secondary,
                isFullWidth: true
            ) {
                viewModel.openCamera()
            }
            
            // Delete images button
            LMSButton(
                viewModel.showReorderMode ? "Hoàn tất" : "Xoá hình ảnh",
                icon: viewModel.showReorderMode ? "checkmark" : "trash.fill",
                variant: viewModel.showReorderMode ? .primary : .destructive,
                isFullWidth: true
            ) {
                viewModel.toggleReorderMode()
            }
        }
    }
    
    private var bottomActionsView: some View {
        HStack(spacing: 20) {
            // Button 1: Đã kiểm tra (Pass)
            VStack(spacing: 8) {
                Button(action: {
                    viewModel.saveValidation(status: .passed)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 60, height: 60)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: Layout.buttonIconSize))
                            .foregroundColor(.green)
                    }
                }
                .scaleEffect(passPressed ? 0.92 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: passPressed)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .updating($passPressed) { _, state, _ in state = true }
                )

                Text("Đã kiểm tra")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }

            // Button 2: Không áp dụng (Not Applicable)
            VStack(spacing: 8) {
                Button(action: {
                    viewModel.saveValidation(status: .notApplicable)
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 60, height: 60)

                        Image(systemName: "slash.circle.fill")
                            .font(.system(size: Layout.buttonIconSize))
                            .foregroundColor(.gray)
                    }
                }
                .scaleEffect(naPressed ? 0.92 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: naPressed)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .updating($naPressed) { _, state, _ in state = true }
                )

                Text("Không áp dụng")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(
            Color(.systemBackground)
                .shadow(color: LMSColor.shadow.opacity(0.2), radius: 8, x: 0, y: -2)
                .ignoresSafeArea()
        )
    }
    
    // MARK: - Upload Toast

    private var uploadToastView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: viewModel.uploadProgress >= 1.0
                      ? "checkmark.circle.fill"
                      : "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(viewModel.uploadProgress >= 1.0 ? .green : LMSColor.primary)
                    .animation(.easeOut(duration: 0.3), value: viewModel.uploadProgress)

                Text(viewModel.uploadProgress >= 1.0 ? "Đã tải lên" : "Đang tải ảnh lên...")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()
            }

            LMSUploadProgressBar(
                mode: viewModel.uploadProgress >= 1.0 ? .determinate(1.0) : .indeterminate,
                height: 4
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 6)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Image Action Handlers

    private func handleEditImage() async {
        guard let index = selectedImageIndex, viewModel.images.indices.contains(index) else { return }
        let img = viewModel.images[index]
        if let remoteURL = img.remoteURL {
            viewModel.isDownloading = true
            do {
                let downloaded = try await viewModel.downloadImage(from: remoteURL)
                viewModel.isDownloading = false
                editingUIImage = downloaded
                showImageEditor = true
            } catch {
                viewModel.isDownloading = false
                viewModel.snackbarMessage = "Không thể tải ảnh. Vui lòng thử lại."
            }
        } else {
            editingUIImage = img.image
            showImageEditor = true
        }
    }

    private func handleShareImage() async {
        guard let index = selectedImageIndex, viewModel.images.indices.contains(index) else { return }
        let img = viewModel.images[index]
        if let remoteURL = img.remoteURL {
            viewModel.isDownloading = true
            do {
                let downloaded = try await viewModel.downloadImage(from: remoteURL)
                viewModel.isDownloading = false
                sharingImage = downloaded
                showShareSheet = true
            } catch {
                viewModel.isDownloading = false
                viewModel.snackbarMessage = "Không thể tải ảnh. Vui lòng thử lại."
            }
        } else {
            sharingImage = img.image
            showShareSheet = true
        }
    }

    // MARK: - Helper Methods

    private func statusColor(for status: ValidationStatus) -> Color {
        switch status {
        case .passed:
            return .green
        case .failed:
            return .red
        case .pending:
            return .orange
        case .notApplicable:
            return .gray
        }
    }
}

// MARK: - Helper Views

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Clear background view for fullScreenCover
struct ClearBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Preview

#Preview("With Images") {
    NavigationStack {
        InspectionValidationView(
            fieldId: "field1",
            fieldLabel: "Carton Overview",
            initialImages: [
                InspectionImage(image: UIImage(systemName: "photo")!),
                InspectionImage(image: UIImage(systemName: "photo.fill")!),
                InspectionImage(image: UIImage(systemName: "photo.circle")!),
                InspectionImage(image: UIImage(systemName: "photo.circle.fill")!)
            ]
        ) { validation in
            print("Saved: \(validation)")
        }
    }
}

#Preview("Empty State") {
    NavigationStack {
        InspectionValidationView(
            fieldId: "field1",
            fieldLabel: "Carton Overview",
            initialImages: []
        ) { validation in
            print("Saved: \(validation)")
        }
    }
}

#Preview("Dark Mode") {
    NavigationStack {
        InspectionValidationView(
            fieldId: "field1",
            fieldLabel: "Carton Overview",
            initialImages: [
                InspectionImage(image: UIImage(systemName: "photo")!),
                InspectionImage(image: UIImage(systemName: "photo.fill")!)
            ]
        ) { validation in
            print("Saved: \(validation)")
        }
    }
    .preferredColorScheme(.dark)
}
