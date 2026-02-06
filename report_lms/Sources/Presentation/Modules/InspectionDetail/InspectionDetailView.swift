//
//  InspectionDetailView.swift
//  report_lms
//
//  Created by GitHub Copilot on 1/2/26.
//

import SwiftUI

struct InspectionDetailView: View {
    // MARK: - Constants
    private enum Layout {
        static let sectionSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 16
        static let errorIconSize: CGFloat = 48
        static let errorSpacing: CGFloat = 16
        static let retryButtonMaxWidth: CGFloat = 200
        static let retryButtonHeight: CGFloat = 44
        static let toolbarIconSize: CGFloat = 24
    }

    // MARK: - Properties
    @StateObject private var viewModel: InspectionDetailViewModel
    @Environment(\.dismiss) private var dismiss

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
                LMSLoadingOverlay()
            }
        }
        .navigationTitle(viewModel.inspectionDetail?.inspectionNumber ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                submitButton
            }
        }
        .task {
            await viewModel.loadInspectionDetail()
        }
        .navigationDestination(isPresented: $viewModel.showCamera) {
            CameraView(source: .inspection) { images in
                viewModel.handlePhotoSelection(images)
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
            LazyVStack(spacing: Layout.sectionSpacing) {
                ForEach(detail.sections.sorted(by: { $0.order < $1.order })) { section in
                    sectionView(for: section)
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func sectionView(for section: InspectionSection) -> some View {
        InspectionSectionView(
            title: section.title,
            itemCount: section.itemCount,
            isExpanded: viewModel.isExpanded(section.id),
            onToggle: { viewModel.toggleSection(section.id) },
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
            hasPhoto: viewModel.hasPhoto(for: field.id),
            images: viewModel.getImages(for: field.id),
            onCameraTap: { viewModel.openPhotoPicker(for: field.id) }
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

    private var submitButton: some View {
        Button(action: {
            Task {
                await viewModel.submitInspection()
            }
        }, label: {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: Layout.toolbarIconSize))
        })
    }

    private var retryButton: some View {
        LMSButton("Thử lại", icon: "arrow.clockwise", variant: .primary, action: {
            Task {
                await viewModel.loadInspectionDetail()
            }
        })
        .frame(maxWidth: Layout.retryButtonMaxWidth)
        .frame(height: Layout.retryButtonHeight)
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
