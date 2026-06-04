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
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @Namespace private var tabBarNamespace
    @State private var tabBarVisible = false
    @GestureState private var submitPressed = false

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
        .lmsSnackbar(message: $viewModel.snackbarMessage, type: .success)
        .navigationTitle(viewModel.inspection?.inspectionNumber ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                submitButton
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) { tabBarVisible = true }
        }
        .task {
            await viewModel.loadInspectionDetail()
        }
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            CameraView(source: .inspection) { images in
                viewModel.handlePhotoSelection(images)
            }
        }
        .navigationDestination(item: $viewModel.selectedValidationField) { field in
            InspectionValidationView(
                fieldId: field.id,
                fieldLabel: field.label,
                initialImages: viewModel.getImages(for: field.id),
                inspectionId: viewModel.inspection?.id,
                onSave: { validation in
                    viewModel.handleValidationSave(validation)
                },
                onUploadComplete: {
                    viewModel.refreshInspection()
                    viewModel.snackbarMessage = "Ảnh đã được lưu thành công!"
                }
            )
        }
        .navigationDestination(item: $viewModel.selectedErrorItem) { item in
            PhotoCaptureErrorReviewView(
                inspectionId: viewModel.inspectionId,
                initialImages: item.imageURLs.enumerated().map { index, url in
                    ImageWithNote(
                        source: .remote(url: url),
                        note: index < item.imageNotes.count ? item.imageNotes[index] : ""
                    )
                },
                editingItem: item,
                onImagesUpdated: { _ in },
                onSaved: { saved, images in
                    print("🔍 [InspectionDetailView] onSaved callback triggered")
                    viewModel.errorHomeViewModel.upsertErrorItem(saved, thumbnails: images)
                    viewModel.errorHomeViewModel.scrollToTopTrigger += 1
                },
                onDeleted: { deletedItem in
                    print("🔍 [InspectionDetailView] onDeleted callback triggered")
                    viewModel.errorHomeViewModel.deleteErrorItem(deletedItem)
                }
            )
            .onAppear {
                print("🔍 [InspectionDetailView] navigationDestination appeared for item: \(item.id)")
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
        .opacity(tabBarVisible ? 1 : 0)
        .animation(.easeOut(duration: 0.4), value: tabBarVisible)
    }
    
    private func tabButton(for tab: InspectionDetailViewModel.Tab) -> some View {
        Button(action: {
            viewModel.selectedTab = tab
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
                localizationManager.localize(tab.title),
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
                    errorMessage: viewModel.errorMessage,
                    onSwitchToErrorTab: { viewModel.selectedTab = .error },
                    onErrorSaved: { saved, images in
                        viewModel.errorHomeViewModel.upsertErrorItem(saved, thumbnails: images)
                        viewModel.errorHomeViewModel.scrollToTopTrigger += 1
                    }
                )
            case .error:
                errorTabContent
            case .orderInformation:
                orderInformationContent
            }
        }
        .frame(maxWidth: .infinity, minHeight: Layout.minContentHeight)
        .background(Color(.systemGroupedBackground))
    }
    
    private var errorTabContent: some View {
        ErrorHomeView(
            viewModel: viewModel.errorHomeViewModel,
            onItemTapped: { item in
                print("🔍 [InspectionDetailView] errorTabContent onItemTapped callback")
                print("   - Item ID: \(item.id)")
                print("   - Setting selectedErrorItem...")
                viewModel.selectedErrorItem = item
                print("   - selectedErrorItem set ✅")
            }
        )
    }
    
    private var orderInformationContent: some View {
        InformationPurchaseView(inspection: viewModel.inspection)
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
        .scaleEffect(submitPressed ? 0.88 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: submitPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($submitPressed) { _, state, _ in state = true }
        )
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
