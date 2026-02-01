//
//  InspectionDetailView.swift
//  report_lms
//
//  Created by GitHub Copilot on 1/2/26.
//

import SwiftUI
import PhotosUI

struct InspectionDetailView: View {
    // MARK: - Properties
    @StateObject private var viewModel: InspectionDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhoto: PhotosPickerItem?
    
    // MARK: - Initialization
    init(inspectionId: String, inspectionNumber: String) {
        _viewModel = StateObject(
            wrappedValue: InspectionDetailViewModel(
                inspectionId: inspectionId,
                inspectionNumber: inspectionNumber
            )
        )
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            contentView
            
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .navigationTitle(viewModel.inspectionDetail?.inspectionNumber ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await viewModel.submitInspection()
                    }
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 24))
                }
            }
        }
        .task {
            await viewModel.loadInspectionDetail()
        }
        .photosPicker(
            isPresented: $viewModel.showPhotoPicker,
            selection: $selectedPhoto,
            matching: .images
        )
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    viewModel.handlePhotoSelection(image)
                }
                selectedPhoto = nil
            }
        }
    }
    
    // MARK: - Private Views
    private var contentView: some View {
        Group {
            if let detail = viewModel.inspectionDetail {
                sectionListView(detail: detail)
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            } else {
                EmptyView()
            }
        }
    }
    
    private func sectionListView(detail: InspectionDetail) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(detail.sections.sorted(by: { $0.order < $1.order })) { section in
                    InspectionSectionView(
                        title: section.title,
                        itemCount: section.itemCount,
                        isExpanded: viewModel.isExpanded(section.id),
                        onToggle: {
                            viewModel.toggleSection(section.id)
                        }
                    ) {
                        VStack(spacing: 0) {
                            ForEach(Array(section.fields.enumerated()), id: \.element.id) { index, field in
                                InspectionFieldItemView(
                                    fieldName: field.label,
                                    hasPhoto: viewModel.hasPhoto(for: field.id),
                                    onCameraTap: {
                                        viewModel.openPhotoPicker(for: field.id)
                                    }
                                )
                                
                                if index < section.fields.count - 1 {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            LMSLabel(message, style: .body, alignment: .center)
            
            LMSButton("Thử lại", icon: "arrow.clockwise", variant: .primary) {
                Task {
                    await viewModel.loadInspectionDetail()
                }
            }
            .frame(maxWidth: 200)
            .frame(height: 44)
        }
        .padding()
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                
                LMSLabel("Đang tải...", style: .body, color: .custom(.white))
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray))
            )
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        InspectionDetailView(
            inspectionId: "1",
            inspectionNumber: "001"
        )
    }
}

#Preview("Dark Mode") {
    NavigationStack {
        InspectionDetailView(
            inspectionId: "1",
            inspectionNumber: "001"
        )
    }
    .preferredColorScheme(.dark)
}
