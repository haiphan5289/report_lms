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
        static let toolbarIconSize: CGFloat = 24
        static let tabIconSize: CGFloat = 18
        static let tabSpacing: CGFloat = 4
        static let tabUnderlineHeight: CGFloat = 3
        static let tabBottomPadding: CGFloat = 2
        static let minContentHeight: CGFloat = 120
    }

    // MARK: - Properties
    @StateObject private var viewModel: InspectionDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Namespace private var tabBarNamespace

    // MARK: - Initialization
    init(inspectionId: String, inspectionNumber: String, homeViewModel: LMSHomeViewModel? = nil) {
        _viewModel = StateObject(
            wrappedValue: InspectionDetailViewModel(
                inspectionId: inspectionId,
                inspectionNumber: inspectionNumber,
                homeViewModel: homeViewModel
            )
        )
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                tabBar
                tabContent
            }

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
        .navigationDestination(isPresented: $viewModel.showValidation) {
            if let field = viewModel.selectedValidationField {
                InspectionValidationView(
                    fieldId: field.id,
                    fieldLabel: field.label,
                    initialImages: viewModel.getImages(for: field.id)
                ) { validation in
                    viewModel.handleValidationSave(validation)
                }
            }
        }
    }

    // MARK: - Private Views
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(InspectionDetailViewModel.Tab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .bottom)
        .padding(.bottom, Layout.tabBottomPadding)
    }
    
    private func tabButton(for tab: InspectionDetailViewModel.Tab) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                viewModel.selectedTab = tab
            }
        }, label: {
            tabButtonContent(for: tab)
        })
        .buttonStyle(.plain)
    }
    
    private func tabButtonContent(for tab: InspectionDetailViewModel.Tab) -> some View {
        let isSelected = viewModel.selectedTab == tab

        return VStack(spacing: Layout.tabSpacing) {
            Image(systemName: tab.icon)
                .font(.system(size: Layout.tabIconSize, weight: .semibold))
                .foregroundColor(isSelected ? .accentColor : .secondary)

            LMSLabel(
                tab.title,
                style: .body,
                color: isSelected ? .custom(Color.accentColor) : .secondary,
                alignment: .center
            )
            .fontWeight(isSelected ? .semibold : .regular)

            tabUnderline(isSelected: isSelected)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 0)
    }
    
    private func tabUnderline(isSelected: Bool) -> some View {
        ZStack {
            if isSelected {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(height: Layout.tabUnderlineHeight)
                    .matchedGeometryEffect(id: "tabUnderline", in: tabBarNamespace)
            } else {
                Color.clear.frame(height: Layout.tabUnderlineHeight)
            }
        }
    }
    
    private var tabContent: some View {
        Group {
            switch viewModel.selectedTab {
            case .inspectionDetail:
                InspectionDetailContentView(
                    contentViewModel: viewModel.contentViewModel,
                    onRetry: { await viewModel.loadInspectionDetail() },
                    errorMessage: viewModel.errorMessage
                )
            case .error:
                errorTabContent
            case .orderInformation:
                orderInformationContent
            }
        }
        .frame(maxWidth: .infinity, minHeight: Layout.minContentHeight)
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut, value: viewModel.selectedTab)
    }
    
    private var errorTabContent: some View {
        ErrorHomeView(
            viewModel: ErrorHomeViewModel(),
            onNavigateToPhotoCaptureErrorReview: {
                // Handle navigation if needed
            }
        )
    }
    
    private var orderInformationContent: some View {
        InformationPurchaseView()
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
