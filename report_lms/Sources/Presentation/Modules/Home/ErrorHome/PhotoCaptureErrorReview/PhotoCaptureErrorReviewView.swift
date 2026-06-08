//
//  PhotoCaptureReviewView.swift
//  report_lms
//
//  Created by GitHub Copilot on 2/4/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

// MARK: - Photo Capture Error Review View
struct PhotoCaptureErrorReviewView: View {
    // MARK: - Constants
    private enum Layout {
        static let outerSpacing: CGFloat = 24
        static let sectionSpacing: CGFloat = 16
        static let innerSpacing: CGFloat = 12
        static let cornerRadius: CGFloat = 8
        static let shadowRadius: CGFloat = 2
        static let imageGridSpacing: CGFloat = 8
        static let textEditorMinHeight: CGFloat = 100
        static let textEditorPadding: CGFloat = 12
        static let sectionPadding: CGFloat = 16
        static let numberChipHPadding: CGFloat = 12
        static let numberChipVPadding: CGFloat = 8
    }

    // MARK: - Properties
    @StateObject private var viewModel: PhotoCaptureErrorReviewViewModel
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    let initialImages: [ImageWithNote]
    let onImagesUpdated: ([ImageWithNote]) -> Void
    let onSaved: (SavedErrorItem, [UIImage]) -> Void
    let onDeleted: ((SavedErrorItem) -> Void)?
    private let editingItem: SavedErrorItem?

    @State private var showingDefectTypeList = false
    @State private var showDeleteConfirmation = false
    @State private var defectTypeSearchableVM: SearchableListViewModel?

    // Image action menu
    @State private var selectedImageIndex: Int?
    @State private var showImageMenu = false
    @State private var showImageEditor = false
    @State private var editingUIImage: UIImage?
    @State private var sharingImage: UIImage?
    @State private var showShareSheet = false

    // Animation
    @State private var heroVisible = false
    @State private var floatOffset: CGFloat = -6
    @State private var imageRefreshTrigger: Int = 0

    // MARK: - Initialization
    init(
        inspectionId: String,
        initialImages: [ImageWithNote],
        editingItem: SavedErrorItem? = nil,
        onImagesUpdated: @escaping ([ImageWithNote]) -> Void,
        onSaved: @escaping (SavedErrorItem, [UIImage]) -> Void = { _, _ in },
        onDeleted: ((SavedErrorItem) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: PhotoCaptureErrorReviewViewModel(inspectionId: inspectionId, editingItem: editingItem))
        self.initialImages = initialImages
        self.editingItem = editingItem
        self.onImagesUpdated = onImagesUpdated
        self.onSaved = onSaved
        self.onDeleted = onDeleted
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.outerSpacing) {
                imagesSection
                    .opacity(heroVisible ? 1 : 0)
                    .offset(y: heroVisible ? 0 : 16)
                    .animation(.easeOut(duration: 0.4), value: heroVisible)
                takeMorePhotosSection
                    .opacity(heroVisible ? 1 : 0)
                    .offset(y: heroVisible ? 0 : 16)
                    .animation(.easeOut(duration: 0.4).delay(0.08), value: heroVisible)
                severityLevelSection
                    .opacity(heroVisible ? 1 : 0)
                    .offset(y: heroVisible ? 0 : 16)
                    .animation(.easeOut(duration: 0.4).delay(0.16), value: heroVisible)
                generalConditionSection
                    .opacity(heroVisible ? 1 : 0)
                    .offset(y: heroVisible ? 0 : 16)
                    .animation(.easeOut(duration: 0.4).delay(0.24), value: heroVisible)
                defectTypesSection
                    .opacity(heroVisible ? 1 : 0)
                    .offset(y: heroVisible ? 0 : 16)
                    .animation(.easeOut(duration: 0.4).delay(0.32), value: heroVisible)
                commentsSection
                    .opacity(heroVisible ? 1 : 0)
                    .offset(y: heroVisible ? 0 : 16)
                    .animation(.easeOut(duration: 0.4).delay(0.40), value: heroVisible)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(
            localizationManager.localize(viewModel.isEditMode ? "errorReview.title.edit" : "errorReview.title.new")
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.isEditMode {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizationManager.localize("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(localizationManager.localize("common.done")) {
                        if let saved = viewModel.saveReview() {
                            onImagesUpdated(viewModel.images)
                            onSaved(saved, viewModel.localImages)
                            dismiss()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showCamera) {
            CameraView(source: .errorReport) { newImages in
                viewModel.addImages(newImages)
                onImagesUpdated(viewModel.images)
            }
            .environmentObject(localizationManager)
        }
        .sheet(isPresented: $showingDefectTypeList) {
            if let searchableVM = defectTypeSearchableVM {
                SearchableListView(viewModel: searchableVM) { selectedItem in
                    viewModel.selectDefectType(from: selectedItem)
                    showingDefectTypeList = false
                }
            }
        }
        .onAppear {
            print("🔍 [PhotoCaptureErrorReviewView] onAppear")
            print("   - EditMode: \(viewModel.isEditMode)")
            print("   - InspectionId: \(viewModel.inspectionId)")
            print("   - EditingItem: \(editingItem?.id ?? "nil")")
            print("   - initialImages count: \(initialImages.count)")
            for (i, img) in initialImages.enumerated() {
                print("   - initialImages[\(i)]: \(img.source)")
            }
            print("   - viewModel.images BEFORE setInitialImages: \(viewModel.images.count)")
            Task {
                await viewModel.setInitialImages(initialImages)
                print("   ✅ setInitialImages done — viewModel.images: \(viewModel.images.count)")
            }
        }
        .onDisappear {
            print("🔍 [PhotoCaptureErrorReviewView] onDisappear — viewModel.images: \(viewModel.images.count)")
        }
        .task {
            withAnimation { heroVisible = true }
        }
        .alert(
            localizationManager.localize("common.error"),
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(localizationManager.localize("common.ok")) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .confirmationDialog(
            localizationManager.localize("errorReview.delete.title"),
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(localizationManager.localize("errorReview.delete.confirm"), role: .destructive) {
                guard let item = editingItem else { return }
                onDeleted?(item)
                dismiss()
            }
            Button(localizationManager.localize("common.cancel"), role: .cancel) {}
        }
        .overlay {
            if viewModel.isDownloading {
                LMSLoadingOverlay()
            }
        }
        .confirmationDialog("", isPresented: $showImageMenu) {
            Button(localizationManager.localize("imageEditor.menu.edit")) {
                Task { await handleEditImage() }
            }
            Button(localizationManager.localize("imageEditor.menu.share")) {
                Task { await handleShareImage() }
            }
            Button(localizationManager.localize("imageEditor.menu.delete"), role: .destructive) {
                if let index = selectedImageIndex {
                    viewModel.deleteImage(at: index)
                    onImagesUpdated(viewModel.images)
                }
            }
            Button(localizationManager.localize("common.cancel"), role: .cancel) {}
        }
        .sheet(isPresented: $showImageEditor) {
            if let image = editingUIImage, let index = selectedImageIndex {
                ImageEditorView(image: image) { editedImage in
                    print("🔍 [PhotoCaptureErrorReviewView] ImageEditor callback")
                    print("   - Edited image size: \(editedImage.size)")
                    viewModel.replaceImage(at: index, with: editedImage)
                    onImagesUpdated(viewModel.images)
                    // Force view refresh
                    imageRefreshTrigger += 1
                    print("   - Refresh trigger: \(imageRefreshTrigger)")
                }
                .environmentObject(localizationManager)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = sharingImage {
                ShareSheet(items: [image])
            }
        }
        .lmsSnackbar(message: $viewModel.snackbarMessage, type: .error)
        .safeAreaInset(edge: .bottom) {
            if viewModel.isEditMode {
                actionButtonsSection
                    .opacity(heroVisible ? 1 : 0)
                    .offset(y: heroVisible ? 0 : 16)
                    .animation(.easeOut(duration: 0.4).delay(0.48), value: heroVisible)
            }
        }
    }

    // MARK: - Images Section
    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: Layout.innerSpacing) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LMSColor.primary)
                    .frame(width: 3, height: 20)
                LMSLabel(localizationManager.localize("errorReview.section.images"), style: .title2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.images.isEmpty {
                VStack(spacing: Layout.innerSpacing) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(LMSColor.textTertiary)
                        .offset(y: floatOffset)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                                floatOffset = 6
                            }
                        }
                    LMSLabel(localizationManager.localize("errorReview.images.empty"), style: .body)
                        .foregroundColor(LMSTextColor.secondary.color)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: Layout.imageGridSpacing) {
                    ForEach(Array(viewModel.images.enumerated()), id: \.element.id) { index, imageWithNote in
                        ImageRowCard(
                            source: imageWithNote.source,
                            index: index,
                            total: viewModel.images.count,
                            note: Binding(
                                get: { viewModel.images[index].note },
                                set: { viewModel.images[index].note = $0 }
                            ),
                            cornerRadius: Layout.cornerRadius
                        ) {
                            selectedImageIndex = index
                            showImageMenu = true
                        }
                        .id("\(imageWithNote.id)-\(imageRefreshTrigger)")
                    }
                }
            }
        }
        .padding(Layout.sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.06), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Take More Photos Section
    
    private var takeMorePhotosSection: some View {
        VStack(alignment: .leading, spacing: Layout.innerSpacing) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LMSColor.primary)
                    .frame(width: 3, height: 20)
                LMSLabel(localizationManager.localize("errorReview.section.takeMorePhotos"), style: .title2)
            }

            LMSButton(
                localizationManager.localize("errorReview.button.takePhoto"),
                icon: "camera.fill",
                variant: .primary,
                isFullWidth: true
            ) {
                viewModel.showCamera = true
            }
        }
        .padding(Layout.sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.06), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Severity Level Section
    private var severityLevelSection: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LMSColor.primary)
                    .frame(width: 3, height: 20)
                LMSLabel(localizationManager.localize("errorReview.section.severity"), style: .title2)
            }

            VStack(spacing: Layout.innerSpacing) {
                ForEach(SeverityLevel.allCases, id: \.self) { level in
                    HStack {
                        Image(systemName: viewModel.selectedSeverity == level ? "circle.inset.filled" : "circle")
                            .foregroundColor(
                                viewModel.selectedSeverity == level ? LMSColor.primary : LMSColor.textTertiary
                            )
                        LMSLabel(level.displayName, style: .body)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectedSeverity = level
                    }
                }
            }
        }
        .padding(Layout.sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.06), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - General Condition Section
    private var generalConditionSection: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            HStack {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LMSColor.primary)
                        .frame(width: 3, height: 20)
                    LMSLabel(localizationManager.localize("errorReview.section.generalCondition"), style: .title2)
                }
                Spacer()
                Toggle("", isOn: $viewModel.generalConditionEnabled)
                    .labelsHidden()
            }

            if viewModel.generalConditionEnabled {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [GridItem(.flexible())], spacing: Layout.sectionSpacing) {
                        ForEach(1...10, id: \.self) { number in
                            let isSelected = viewModel.selectedGeneralCondition == number
                            LMSLabel("\(number)", style: .body)
                                .padding(.horizontal, Layout.numberChipHPadding)
                                .padding(.vertical, Layout.numberChipVPadding)
                                .background(
                                    RoundedRectangle(cornerRadius: Layout.cornerRadius)
                                        .fill(isSelected ? LMSColor.primaryLight : LMSColor.backgroundSecondary)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: Layout.cornerRadius)
                                        .stroke(
                                            isSelected ? LMSColor.primary : LMSColor.secondary,
                                            lineWidth: 1
                                        )
                                )
                                .onTapGesture {
                                    viewModel.selectedGeneralCondition = number
                                }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
        .padding(Layout.sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.06), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Defect Types Section
    private var defectTypesSection: some View {
        VStack(alignment: .leading, spacing: Layout.innerSpacing) {
            if let defectType = viewModel.selectedDefectType {
                HStack {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LMSColor.primary)
                            .frame(width: 3, height: 20)
                        LMSLabel(localizationManager.localize("errorReview.section.defectTypes"), style: .title2)
                    }
                    Spacer()
                    Button(action: {
                        viewModel.selectedDefectType = nil
                    }, label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(LMSColor.textTertiary)
                    })
                }
                LMSLabel(defectType.displayName, style: .body)
                    .foregroundColor(LMSTextColor.secondary.color)
                    .lineLimit(2)
            } else {
                HStack {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LMSColor.primary)
                            .frame(width: 3, height: 20)
                        LMSLabel(localizationManager.localize("errorReview.section.defectTypes"), style: .title2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(LMSColor.textTertiary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    defectTypeSearchableVM = SearchableListViewModel(
                        sections: viewModel.defectTypeSearchableData(),
                        title: localizationManager.localize("errorReview.section.defectTypes")
                    )
                    showingDefectTypeList = true
                }
            }
        }
        .padding(Layout.sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.06), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Comments Section
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: Layout.innerSpacing) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LMSColor.primary)
                    .frame(width: 3, height: 20)
                LMSLabel(localizationManager.localize("errorReview.section.comments"), style: .title2)
            }

            TextEditor(text: $viewModel.comments)
                .frame(minHeight: Layout.textEditorMinHeight)
                .padding(Layout.textEditorPadding)
                .background(LMSColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.cornerRadius)
                        .stroke(LMSColor.secondary, lineWidth: 1)
                )
        }
        .padding(Layout.sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.06), radius: 8, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        HStack(spacing: Layout.sectionSpacing) {
            LMSButton(
                localizationManager.localize("errorReview.button.delete"),
                icon: "trash.fill",
                variant: .destructive
            ) {
                showDeleteConfirmation = true
            }

            LMSButton(
                localizationManager.localize("errorReview.button.saveChanges"),
                icon: "pencil",
                variant: .primary
            ) {
                if let saved = viewModel.updateReview() {
                    onImagesUpdated(viewModel.images)
                    onSaved(saved, viewModel.localImages)
                    dismiss()
                }
            }
        }
        .padding(Layout.sectionPadding)
        .background(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(color: Color.primary.opacity(0.08), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadius)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Image Action Handlers
    private func handleEditImage() async {
        guard let index = selectedImageIndex else { return }
        print("🔍 [PhotoCaptureErrorReviewView] handleEditImage")
        print("   - Index: \(index)")
        print("   - Source: \(viewModel.images[index].source)")
        
        switch viewModel.images[index].source {
        case .local(let img):
            print("   - Local image size: \(img.size)")
            editingUIImage = img
            showImageEditor = true
        case .remote(let url):
            print("   - Downloading remote image...")
            viewModel.isDownloading = true
            do {
                let img = try await viewModel.downloadImage(from: url)
                print("   - Downloaded image size: \(img.size)")
                viewModel.isDownloading = false
                editingUIImage = img
                showImageEditor = true
            } catch {
                print("   - Download failed: \(error)")
                viewModel.isDownloading = false
                viewModel.snackbarMessage = localizationManager.localize("imageEditor.error.downloadFailed")
            }
        }
    }

    private func handleShareImage() async {
        guard let index = selectedImageIndex else { return }
        switch viewModel.images[index].source {
        case .local(let img):
            sharingImage = img
            showShareSheet = true
        case .remote(let url):
            viewModel.isDownloading = true
            do {
                let img = try await viewModel.downloadImage(from: url)
                viewModel.isDownloading = false
                sharingImage = img
                showShareSheet = true
            } catch {
                viewModel.isDownloading = false
                viewModel.snackbarMessage = localizationManager.localize("imageEditor.error.downloadFailed")
            }
        }
    }

}

// MARK: - Image Row Card

private struct ImageRowCard: View {
    let source: ImageSource
    let index: Int
    let total: Int
    @Binding var note: String
    let cornerRadius: CGFloat
    let onMenu: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Full-width image with overlaid controls
            ZStack(alignment: .topTrailing) {
                imageContent
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

                // Index badge top-left
                Text("\(index + 1) / \(total)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                    )
                    .shadow(color: Color.primary.opacity(0.12), radius: 6, y: 3)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                // Menu button top-right
                Button(action: onMenu) {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.primary)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: Color.primary.opacity(0.18), radius: 6, y: 3)
                        .padding(8)
                }
            }

            // Note text field
            TextField("Thêm ghi chú cho ảnh này...", text: $note, axis: .vertical)
                .font(.system(size: 14))
                .foregroundColor(LMSColor.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .background(LMSColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(LMSColor.secondary, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var imageContent: some View {
        switch source {
        case .local(let image):
            Image(uiImage: image)
                .resizable()
                .onAppear {
                    print("🔍 [ImageRowCard] Rendering LOCAL image")
                    print("   - Image size: \(image.size)")
                }
        case .remote(let url):
            CachedAsyncImage(url: URL(string: url)) { phase in
                if let img = phase.image {
                    img.resizable()
                        .onAppear {
                            print("🔍 [ImageRowCard] Rendering REMOTE image SUCCESS")
                        }
                } else {
                    LMSColor.backgroundSecondary
                        .onAppear {
                            print("🔍 [ImageRowCard] Rendering REMOTE placeholder (loading/error)")
                            print("   - URL: \(url)")
                        }
                }
            }
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
#Preview("Empty State") {
    PhotoCaptureErrorReviewView(
        inspectionId: "preview-id",
        initialImages: [],
        onImagesUpdated: { _ in }
    )
    .environmentObject(LocalizationManager.shared)
}

#Preview("With Images") {
    let sampleImage1 = UIImage(systemName: "photo") ?? UIImage()
    let sampleImage2 = UIImage(systemName: "photo.fill") ?? UIImage()

    return PhotoCaptureErrorReviewView(
        inspectionId: "preview-id",
        initialImages: [
            ImageWithNote(source: .local(image: sampleImage1), note: "Carton bị móp"),
            ImageWithNote(source: .local(image: sampleImage2))
        ],
        onImagesUpdated: { _ in }
    )
    .environmentObject(LocalizationManager.shared)
}
