//
//  PhotoCaptureReviewView.swift
//  report_lms
//
//  Created by GitHub Copilot on 2/4/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

// MARK: - Photo Capture Review View
struct PhotoCaptureReviewView: View {
    @StateObject private var viewModel = PhotoCaptureReviewViewModel()
    @Environment(\.dismiss) private var dismiss
    let initialImages: [UIImage]
    let onImagesUpdated: ([UIImage]) -> Void
    
    @State private var showingDefectTypeList = false

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
                }
                .padding()
            }
            .navigationTitle("Đánh giá ảnh chụp")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Hủy") {
                    dismiss()
                },
                trailing: Button("Hoàn thành") {
                    // Handle completion
                    dismiss()
                }
            )
            .sheet(isPresented: $viewModel.showCamera) {
                CameraView(onPhotoCaptured: { newImages in
                    viewModel.addImages(newImages)
                    onImagesUpdated(viewModel.images)
                })
            }
            .sheet(isPresented: $showingDefectTypeList) {
                let defectData = createDefectTypeSearchableData()
                let searchableViewModel = SearchableListViewModel(items: defectData)
                
                SearchableListView(viewModel: searchableViewModel) { selectedItem in
                    handleDefectTypeSelection(selectedItem)
                    showingDefectTypeList = false
                }
            }
            .onAppear {
                viewModel.setInitialImages(initialImages)
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
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(alignment: .center, spacing: 12) {
                        ForEach(viewModel.images.indices, id: \.self) { index in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: viewModel.images[index])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                Button(action: {
                                    viewModel.deleteImage(at: index)
                                    onImagesUpdated(viewModel.images)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                        .padding(4)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    // MARK: - Take More Photos Section
    private var takeMorePhotosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            LMSLabel("Chụp thêm ảnh", style: .title2)

            LMSButton("Chụp ảnh", icon: "camera.fill", variant: .primary) {
                viewModel.showCamera = true
            }
        }
        .padding()
        .background(Color.white)
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
        .background(Color.white)
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
                                        .fill(viewModel.selectedGeneralCondition == number ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(viewModel.selectedGeneralCondition == number ? Color.blue : Color.gray, lineWidth: 1)
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
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 2)
    }

    // MARK: - Defect Types Section
    private var defectTypesSection: some View {
        ProductInfoInput(
            title: "Các loại phân lỗi",
            text: .constant(viewModel.selectedDefectType?.displayName ?? "Chọn loại phân lỗi"),
            type: .dropdown,
            onDropdownTap: {
                showingDefectTypeList = true
            }
        )
        .padding()
        .background(Color.white)
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
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 2)
    }
    
    // MARK: - Private Methods
    private func createDefectTypeSearchableData() -> ListItemProtocol {
        SampleListItem(
            title: "Các loại phân lỗi",
            datas: DefectType.allCases.map { defect in
                ListDataItem(id: defect.hashValue, name: defect.displayName)
            }
        )
    }
    
    private func handleDefectTypeSelection(_ selectedItem: ListDataItem) {
        if let defectType = DefectType.allCases.first(where: { $0.displayName == selectedItem.name }) {
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
    PhotoCaptureReviewView(
        initialImages: [],
        onImagesUpdated: { _ in }
    )
}

#Preview("With Images") {
    // Create sample images for preview
    let sampleImage1 = UIImage(systemName: "photo") ?? UIImage()
    let sampleImage2 = UIImage(systemName: "photo.fill") ?? UIImage()
    let sampleImage3 = UIImage(systemName: "camera") ?? UIImage()
    
    return PhotoCaptureReviewView(
        initialImages: [sampleImage1, sampleImage2, sampleImage3],
        onImagesUpdated: { _ in }
    )
}
