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

    let initialImages: [ImageSource]
    let onImagesUpdated: ([ImageSource]) -> Void
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

    // MARK: - Initialization
    init(
        inspectionId: String,
        initialImages: [ImageSource],
        editingItem: SavedErrorItem? = nil,
        onImagesUpdated: @escaping ([ImageSource]) -> Void,
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
        NavigationStack {
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
            .navigationTitle(
                localizationManager.localize(viewModel.isEditMode ? "errorReview.title.edit" : "errorReview.title.new")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(localizationManager.localize("common.cancel")) { dismiss() }
                }
                if !viewModel.isEditMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(localizationManager.localize("common.done")) {
                            Task {
                                if let saved = await viewModel.saveReview() {
                                    onImagesUpdated(viewModel.images)
                                    onSaved(saved, viewModel.localImages)
                                    dismiss()
                                }
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
                viewModel.setInitialImages(initialImages)
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
                if viewModel.isLoading || viewModel.isDownloading {
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
                        viewModel.replaceImage(at: index, with: editedImage)
                        onImagesUpdated(viewModel.images)
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
        }
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
            LMSLabel(localizationManager.localize("errorReview.section.images"), style: .title2)
                .frame(maxWidth: .infinity, alignment: .leading)

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
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: Layout.imageGridSpacing
                ) {
                    ForEach(viewModel.images.indices, id: \.self) { index in
                        ImageThumbnailCell(
                            source: viewModel.images[index],
                            cornerRadius: Layout.cornerRadius
                        ) {
                            selectedImageIndex = index
                            showImageMenu = true
                        }
                    }
                }
            }
        }
        .padding(Layout.sectionPadding)
        .background(LMSColor.background)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
        .shadow(color: LMSColor.shadow, radius: Layout.shadowRadius)
    }

    // MARK: - Take More Photos Section
    private var takeMorePhotosSection: some View {
        VStack(alignment: .leading, spacing: Layout.innerSpacing) {
            LMSLabel(localizationManager.localize("errorReview.section.takeMorePhotos"), style: .title2)

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
        .background(LMSColor.background)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
        .shadow(color: LMSColor.shadow, radius: Layout.shadowRadius)
    }

    // MARK: - Severity Level Section
    private var severityLevelSection: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            LMSLabel(localizationManager.localize("errorReview.section.severity"), style: .title2)

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
        .background(LMSColor.background)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
        .shadow(color: LMSColor.shadow, radius: Layout.shadowRadius)
    }

    // MARK: - General Condition Section
    private var generalConditionSection: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            HStack {
                LMSLabel(localizationManager.localize("errorReview.section.generalCondition"), style: .title2)
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
        .background(LMSColor.background)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
        .shadow(color: LMSColor.shadow, radius: Layout.shadowRadius)
    }

    // MARK: - Defect Types Section
    private var defectTypesSection: some View {
        VStack(alignment: .leading, spacing: Layout.innerSpacing) {
            if let defectType = viewModel.selectedDefectType {
                HStack {
                    LMSLabel(localizationManager.localize("errorReview.section.defectTypes"), style: .title2)
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
                    LMSLabel(localizationManager.localize("errorReview.section.defectTypes"), style: .title2)
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
        .background(LMSColor.background)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
        .shadow(color: LMSColor.shadow, radius: Layout.shadowRadius)
    }

    // MARK: - Comments Section
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: Layout.innerSpacing) {
            LMSLabel(localizationManager.localize("errorReview.section.comments"), style: .title2)

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
        .background(LMSColor.background)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
        .shadow(color: LMSColor.shadow, radius: Layout.shadowRadius)
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
                Task {
                    if let saved = await viewModel.updateReview() {
                        onImagesUpdated(viewModel.images)
                        onSaved(saved, viewModel.localImages)
                        dismiss()
                    }
                }
            }
        }
        .padding(Layout.sectionPadding)
        .background(LMSColor.background)
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
        .shadow(color: LMSColor.shadow, radius: Layout.shadowRadius)
    }

    // MARK: - Image Action Handlers
    private func handleEditImage() async {
        guard let index = selectedImageIndex else { return }
        switch viewModel.images[index] {
        case .local(let img):
            editingUIImage = img
            showImageEditor = true
        case .remote(let url):
            viewModel.isDownloading = true
            do {
                let img = try await viewModel.downloadImage(from: url)
                viewModel.isDownloading = false
                editingUIImage = img
                showImageEditor = true
            } catch {
                viewModel.isDownloading = false
                viewModel.snackbarMessage = localizationManager.localize("imageEditor.error.downloadFailed")
            }
        }
    }

    private func handleShareImage() async {
        guard let index = selectedImageIndex else { return }
        switch viewModel.images[index] {
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

    // MARK: - Private Methods
    @ViewBuilder
    private func imageView(for source: ImageSource) -> some View {
        switch source {
        case .local(let image):
            Image(uiImage: image).resizable()
        case .remote(let url):
            CachedAsyncImage(url: URL(string: url)) { phase in
                if let img = phase.image { img.resizable() }
                else { LMSColor.backgroundSecondary }
            }
        }
    }
}

// MARK: - Image Thumbnail Cell

private struct ImageThumbnailCell: View {
    let source: ImageSource
    let cornerRadius: CGFloat
    let onMenu: () -> Void

    @GestureState private var isPressed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            imageContent
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

            Button(action: onMenu, label: {
                Image(systemName: "ellipsis.circle.fill")
                    .foregroundColor(LMSColor.white)
                    .background(LMSColor.black.opacity(0.6))
                    .clipShape(Circle())
                    .padding(4)
            })
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in state = true }
        )
    }

    @ViewBuilder
    private var imageContent: some View {
        switch source {
        case .local(let image):
            Image(uiImage: image).resizable()
        case .remote(let url):
            CachedAsyncImage(url: URL(string: url)) { phase in
                if let img = phase.image { img.resizable() }
                else { LMSColor.backgroundSecondary }
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
        initialImages: [.local(image: sampleImage1), .local(image: sampleImage2)],
        onImagesUpdated: { _ in }
    )
    .environmentObject(LocalizationManager.shared)
}
