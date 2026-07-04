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
        static let animationDuration: Double = 0.35
        static let floatAnimationDuration: Double = 1.8
        static let springResponse: Double = 0.2
        static let springDamping: Double = 0.6
        static let pressedScale: CGFloat = 0.92
        static let bottomBarTopPadding: CGFloat = 12
        static let bottomBarBottomPadding: CGFloat = 6
    }
    
    // MARK: - Properties
    @StateObject private var viewModel: InspectionValidationViewModel
    @Environment(\.dismiss) private var dismiss

    // Animation
    @State private var contentVisible = false
    @State private var emptyIconOffset: CGFloat = -4
    @GestureState private var passPressed = false
    @GestureState private var naPressed = false

    // Image actions
    @State private var selectedImageIndex: Int?
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

    /// Primary init — coordinator owned by InspectionDetailViewModel (long-lived).
    init(
        coordinator: FieldUploadCoordinator,
        fieldLabel: String,
        initialImages: [InspectionImage] = [],
        inspectionId: String? = nil,
        onSave: @escaping (FieldValidation) -> Void,
        onSilentSave: ((FieldValidation) -> Void)? = nil
    ) {
        self.inspectionIdContext = inspectionId
        self.fieldIdContext = coordinator.fieldId
        _viewModel = StateObject(
            wrappedValue: InspectionValidationViewModel(
                coordinator: coordinator,
                fieldLabel: fieldLabel,
                initialImages: initialImages,
                onSave: onSave,
                onSilentSave: onSilentSave
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
                        .animation(.easeOut(duration: Layout.animationDuration), value: contentVisible)
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
        }
        .navigationTitle(viewModel.fieldLabel)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            withAnimation(.easeOut(duration: Layout.animationDuration)) { contentVisible = true }
            await viewModel.loadPendingCaptures()
        }
        .sheet(isPresented: $viewModel.showCamera) {
            CameraView(
                source: .inspection,
                inspectionId: viewModel.coordinator.inspectionId,
                fieldId: viewModel.coordinator.fieldId
            ) { photos in
                viewModel.appendImages(photos)
            }
            .environmentObject(LocalizationManager.shared)
        }
        .sheet(isPresented: $showImageEditor) {
            if let image = editingUIImage, let index = selectedImageIndex {
                ImageEditorView(image: image) { editedImage in
                    print("🔍 [InspectionValidationView] ImageEditorView.onSave — index=\(index), editedSize=\(editedImage.size)")
                    viewModel.replaceImage(at: index, with: editedImage)
                    imageRefreshTrigger += 1
                    print("   - imageRefreshTrigger → \(imageRefreshTrigger)")
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
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: Layout.animationDuration), value: viewModel.isDownloading)
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
            LMSLabel(viewModel.fieldLabel, style: .headline)

            Spacer()

            Button(action: { viewModel.openCamera() }, label: {
                Image(systemName: "camera.fill")
                    .font(.system(size: Layout.iconSize))
                    .foregroundColor(LMSColor.white)
                    .frame(width: 44, height: 44)
                    .background(LMSColor.primary)
                    .clipShape(Circle())
            })
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(Layout.cornerRadius)
        .shadow(color: LMSColor.shadow, radius: 2, x: 0, y: 1)
    }
    
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            LMSLabel(viewModel.fieldLabel, style: .headline)

            Divider()

            // Status (Trạng thái)
            VStack(alignment: .leading, spacing: 8) {
                LMSLabel("Trạng thái", style: .caption, color: .secondary)

                HStack {
                    LMSLabel("Tình trạng hiện tại", style: .body)

                    Spacer()

                    LMSLabel(viewModel.status.displayText, style: .body)
                        .foregroundColor(statusColor(for: viewModel.status))
                }
            }

            Divider()

            // Comments (Nhận xét)
            VStack(alignment: .leading, spacing: 8) {
                LMSLabel("Nhận xét", style: .caption, color: .secondary)

                TextEditor(text: Binding(
                    get: { viewModel.comments },
                    set: { viewModel.updateComments($0) }
                ))
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.cornerRadius)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if viewModel.comments.isEmpty {
                        LMSLabel("Viết nhận xét tại đây", style: .body, color: .secondary)
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
                VStack(spacing: 12) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 40))
                        .foregroundColor(LMSColor.textTertiary)
                        .offset(y: emptyIconOffset)
                        .onAppear {
                            withAnimation(.easeInOut(duration: Layout.floatAnimationDuration).repeatForever(autoreverses: true)) {
                                emptyIconOffset = 4
                            }
                        }
                    LMSLabel("Chưa có ảnh nào", style: .body, color: .secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 16) {
                    ForEach(viewModel.images) { image in
                        ImageGalleryItemView(
                            inspectionImage: image,
                            isReorderMode: viewModel.showReorderMode,
                            onDelete: { viewModel.requestDeleteImage(byId: image.id) },
                            onEdit: {
                                print("🔍 [InspectionValidationView] onEdit tapped — imageId=\(image.id)")
                                selectedImageIndex = viewModel.images.firstIndex(where: { $0.id == image.id })
                                print("   - selectedImageIndex=\(String(describing: selectedImageIndex))")
                                Task { await handleEditImage() }
                            },
                            onShare: {
                                selectedImageIndex = viewModel.images.firstIndex(where: { $0.id == image.id })
                                Task { await handleShareImage() }
                            },
                            descriptionBinding: Binding(
                                get: {
                                    viewModel.images.first(where: { $0.id == image.id })?.description ?? ""
                                },
                                set: { viewModel.updateDescription($0, for: image.id) }
                            ),
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
            passButton
            notApplicableButton
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, Layout.bottomBarTopPadding)
        .padding(.bottom, Layout.bottomBarBottomPadding)
        .background(
            Color(.systemBackground)
                .shadow(color: LMSColor.shadow.opacity(0.2), radius: 8, x: 0, y: -2)
                .ignoresSafeArea()
        )
    }

    private var passButton: some View {
        VStack(spacing: 8) {
            Button(action: { viewModel.saveValidation(status: .passed) }, label: {
                ZStack {
                    Circle()
                        .fill(LMSColor.success.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Layout.buttonIconSize))
                        .foregroundColor(LMSColor.success)
                }
            })
            .scaleEffect(passPressed ? Layout.pressedScale : 1.0)
            .animation(.spring(response: Layout.springResponse, dampingFraction: Layout.springDamping), value: passPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($passPressed) { _, state, _ in state = true }
            )

            LMSLabel("Đã kiểm tra", style: .caption)
        }
    }

    private var notApplicableButton: some View {
        VStack(spacing: 8) {
            Button(action: { viewModel.saveValidation(status: .notApplicable) }, label: {
                ZStack {
                    Circle()
                        .fill(LMSColor.textTertiary.opacity(0.1))
                        .frame(width: 60, height: 60)

                    Image(systemName: "slash.circle.fill")
                        .font(.system(size: Layout.buttonIconSize))
                        .foregroundColor(LMSColor.textTertiary)
                }
            })
            .scaleEffect(naPressed ? Layout.pressedScale : 1.0)
            .animation(.spring(response: Layout.springResponse, dampingFraction: Layout.springDamping), value: naPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($naPressed) { _, state, _ in state = true }
            )

            LMSLabel("Không áp dụng", style: .caption)
        }
    }
    

    // MARK: - Image Action Handlers

    /// Resolves the best available full-resolution image for editing or sharing.
    /// Returns nil only when a remote download fails (snackbar already set).
    private func resolveFullImage(for img: InspectionImage) async -> UIImage? {
        if let remoteURL = img.remoteURL {
            viewModel.isDownloading = true
            defer { viewModel.isDownloading = false }
            do {
                return try await viewModel.downloadImage(from: remoteURL)
            } catch {
                print("   - ❌ Download failed: \(error)")
                viewModel.snackbarMessage = "Không thể tải ảnh. Vui lòng thử lại."
                return nil
            }
        } else if let fileURL = img.fileURL {
            viewModel.isDownloading = true
            defer { viewModel.isDownloading = false }
            return await Task.detached { UIImage(contentsOfFile: fileURL.path) }.value
                ?? img.thumbnail
        }
        return img.thumbnail
    }

    private func handleEditImage() async {
        print("🔍 [InspectionValidationView] handleEditImage()")
        guard let index = selectedImageIndex, viewModel.images.indices.contains(index) else {
            print("   - ⚠️ Guard failed: selectedImageIndex=\(String(describing: selectedImageIndex)), imagesCount=\(viewModel.images.count)")
            return
        }
        let img = viewModel.images[index]
        print("   - index=\(index), isRemote=\(img.isRemote), hasFileURL=\(img.fileURL != nil), hasThumbnail=\(img.thumbnail != nil)")
        guard let image = await resolveFullImage(for: img) else { return }
        editingUIImage = image
        showImageEditor = true
        print("   - ImageEditorView opened")
    }

    private func handleShareImage() async {
        guard let index = selectedImageIndex, viewModel.images.indices.contains(index) else { return }
        let img = viewModel.images[index]
        guard let image = await resolveFullImage(for: img) else { return }
        sharingImage = image
        showShareSheet = true
    }

    // MARK: - Helper Methods

    private func statusColor(for status: ValidationStatus) -> Color {
        switch status {
        case .passed: return LMSColor.success
        case .failed: return LMSColor.destructive
        case .pending: return LMSColor.warning
        case .notApplicable: return LMSColor.textTertiary
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

// UIViewRepresentable shim: clears the dimming layer behind fullScreenCover
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
    let coord = FieldUploadCoordinator(fieldId: "field1", inspectionId: "")
    NavigationStack {
        InspectionValidationView(
            coordinator: coord,
            fieldLabel: "Carton Overview",
            initialImages: [
                InspectionImage(image: UIImage(systemName: "photo") ?? UIImage()),
                InspectionImage(image: UIImage(systemName: "photo.fill") ?? UIImage()),
                InspectionImage(image: UIImage(systemName: "photo.circle") ?? UIImage()),
                InspectionImage(image: UIImage(systemName: "photo.circle.fill") ?? UIImage())
            ]
        ) { validation in
            print("Saved: \(validation)")
        }
    }
}

#Preview("Empty State") {
    let coord = FieldUploadCoordinator(fieldId: "field1", inspectionId: "")
    NavigationStack {
        InspectionValidationView(
            coordinator: coord,
            fieldLabel: "Carton Overview"
        ) { validation in
            print("Saved: \(validation)")
        }
    }
}

#Preview("Dark Mode") {
    let coord = FieldUploadCoordinator(fieldId: "field1", inspectionId: "")
    NavigationStack {
        InspectionValidationView(
            coordinator: coord,
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
