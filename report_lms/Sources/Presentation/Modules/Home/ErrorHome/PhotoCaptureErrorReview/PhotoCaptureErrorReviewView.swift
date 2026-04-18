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
    @StateObject private var viewModel: PhotoCaptureErrorReviewViewModel
    @Environment(\.dismiss) private var dismiss
    let initialImages: [ImageSource]
    let onImagesUpdated: ([ImageSource]) -> Void
    let onSaved: (SavedErrorItem, [UIImage]) -> Void
    let onDeleted: ((SavedErrorItem) -> Void)?
    private let editingItem: SavedErrorItem?

    @State private var showingDefectTypeList = false
    @State private var showDeleteConfirmation = false

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
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Images Section
                    imagesSection

                    // Take More Photos Section
                    takeMorePhotosSection

                    // Severity Level Section
                    severityLevelSection

                    // General Condition Section
                    generalConditionSection

                    // Defect Types Section
                    defectTypesSection

                    // Comments Section
                    commentsSection

                    // Action Buttons Section (edit mode only)
                    if viewModel.isEditMode {
                        actionButtonsSection
                    }
                }
                .padding()
            }
            .navigationTitle(viewModel.isEditMode ? "Chỉnh sửa lỗi" : "Đánh giá ảnh chụp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { dismiss() }
                }
                if !viewModel.isEditMode {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Hoàn thành") {
                            Task {
                                let localImages = viewModel.images.compactMap { source -> UIImage? in
                                    if case .local(let img) = source { return img } else { return nil }
                                }
                                if let saved = await viewModel.saveReview() {
                                    onImagesUpdated(viewModel.images)
                                    onSaved(saved, localImages)
                                    dismiss()
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCamera) {
                CameraView(source: .errorReport, onPhotoCaptured: { newImages in
                    viewModel.addImages(newImages)
                    onImagesUpdated(viewModel.images)
                })
            }
            .sheet(isPresented: $showingDefectTypeList) {
                let sections = createDefectTypeSearchableData()
                let searchableViewModel = SearchableListViewModel(sections: sections, title: "Các loại phân lỗi")

                SearchableListView(viewModel: searchableViewModel) { selectedItem in
                    handleDefectTypeSelection(selectedItem)
                    showingDefectTypeList = false
                }
            }
            .onAppear {
                viewModel.setInitialImages(initialImages)
            }
            .alert("Lỗi", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .confirmationDialog(
                "Bạn có chắc muốn xoá lỗi này không?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Xoá lỗi", role: .destructive) {
                    guard let item = editingItem else { return }
                    onDeleted?(item)
                    dismiss()
                }
                Button("Huỷ", role: .cancel) {}
            }
            .overlay {
                if viewModel.isLoading {
                    LMSLoadingOverlay()
                }
            }
        }
    }

    // MARK: - Images Section
    private var imagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LMSLabel("Ảnh đã chụp", style: .title2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if viewModel.images.isEmpty {
                Text("Chưa có ảnh nào")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
            VStack(spacing: 12) {
                ForEach(viewModel.images.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        imageView(for: viewModel.images[index])
                            .scaledToFill()
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button(action: {
                            viewModel.deleteImage(at: index)
                            onImagesUpdated(viewModel.images)
                        }, label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                                .padding(4)
                        })
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    // MARK: - Take More Photos Section
    private var takeMorePhotosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LMSLabel("Chụp thêm ảnh", style: .title2)

            LMSButton("Chụp ảnh", icon: "camera.fill", variant: .primary, isFullWidth: true) {
                viewModel.showCamera = true
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    // MARK: - Severity Level Section
    private var severityLevelSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            LMSLabel("Mức độ nặng nhẹ", style: .title2)

            VStack(spacing: 12) {
                ForEach(SeverityLevel.allCases, id: \.self) { level in
                    HStack {
                        Image(systemName: viewModel.selectedSeverity == level ? "circle.inset.filled" : "circle")
                            .foregroundColor(viewModel.selectedSeverity == level ? .blue : .gray)
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
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    // MARK: - General Condition Section
    private var generalConditionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                LMSLabel("Tình trạng chung", style: .title2)
                Spacer()
                Toggle("", isOn: $viewModel.generalConditionEnabled)
                    .labelsHidden()
            }

            if viewModel.generalConditionEnabled {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [GridItem(.flexible())], spacing: 16) {
                        ForEach(1...10, id: \.self) { number in
                            LMSLabel("\(number)", style: .body)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(
                                            viewModel.selectedGeneralCondition == number
                                                ? Color.blue.opacity(0.1)
                                                : Color.gray.opacity(0.1)
                                        )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            viewModel.selectedGeneralCondition == number
                                                ? Color.blue
                                                : Color.gray,
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
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    // MARK: - Defect Types Section
    private var defectTypesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let defectType = viewModel.selectedDefectType {
                HStack {
                    LMSLabel("Các loại phân lỗi", style: .title2)
                    Spacer()
                    Button {
                        viewModel.selectedDefectType = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                LMSLabel(defectType.displayName, style: .body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else {
                HStack {
                    LMSLabel("Các loại phân lỗi", style: .title2)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showingDefectTypeList = true
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            LMSButton("Xoá", icon: "trash.fill", variant: .destructive) {
                showDeleteConfirmation = true
            }

            LMSButton("Lưu Thay đổi", icon: "pencil", variant: .primary) {
                Task {
                    let localImages = viewModel.images.compactMap { source -> UIImage? in
                        if case .local(let img) = source { return img } else { return nil }
                    }
                    if let saved = await viewModel.updateReview() {
                        onImagesUpdated(viewModel.images)
                        onSaved(saved, localImages)
                        dismiss()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    // MARK: - Comments Section
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LMSLabel("Viết nhận xét tại đây", style: .title2)

            TextEditor(text: $viewModel.comments)
                .frame(minHeight: 100)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    // MARK: - Private Methods
    @ViewBuilder
    private func imageView(for source: ImageSource) -> some View {
        switch source {
        case .local(let image):
            Image(uiImage: image).resizable()
        case .remote(let url):
            AsyncImage(url: URL(string: url)) { phase in
                if let img = phase.image { img.resizable() }
                else { Color.gray.opacity(0.3) }
            }
        }
    }

    private func createDefectTypeSearchableData() -> [ListItemProtocol] {
        let categories: [String] = ["PA", "SU", "AS", "FU", "SA", "FI", "CO", "FE", "TA"]
        return categories.compactMap { category -> ListItemProtocol? in
            let items = DefectType.allCases.filter { $0.category == category }
            guard !items.isEmpty else { return nil }
            let datas = items.map { ListDataItem(id: $0.rawValue.hashValue, name: $0.displayName) }
            return SampleListItem(title: items[0].categoryDisplayName, datas: datas)
        }
    }

    private func handleDefectTypeSelection(_ selectedItem: ListDataItem) {
        let code = selectedItem.name.components(separatedBy: " - ").first ?? ""
        if let defectType = DefectType(rawValue: code) {
            viewModel.selectedDefectType = defectType
        }
    }
}

// MARK: - Sample List Item for Searchable Data
private struct SampleListItem: ListItemProtocol {
    let title: String?
    let datas: [ListDataItem]
}

// MARK: - Preview
#Preview("Empty State") {
    PhotoCaptureErrorReviewView(
        inspectionId: "preview-id",
        initialImages: [],
        onImagesUpdated: { _ in }
    )
}

#Preview("With Images") {
    let sampleImage1 = UIImage(systemName: "photo") ?? UIImage()
    let sampleImage2 = UIImage(systemName: "photo.fill") ?? UIImage()

    return PhotoCaptureErrorReviewView(
        inspectionId: "preview-id",
        initialImages: [.local(image: sampleImage1), .local(image: sampleImage2)],
        onImagesUpdated: { _ in }
    )
}
