//
//  LMSHomeView.swift
//  report_lms
//
//  Created by AI on January 21, 2026.
//

import SwiftUI

// MARK: - LMSHomeView

struct LMSHomeView: View {
    // MARK: - Constants
    private enum Layout {
        static let headerHorizontalPadding: CGFloat = 8
        static let headerVerticalPadding: CGFloat = 4
        static let iconButtonSize: CGFloat = 44
        static let shadowOpacity: CGFloat = 0.04
        static let shadowRadius: CGFloat = 2
        static let shadowY: CGFloat = 1
        static let tabIconSize: CGFloat = 18
        static let tabSpacing: CGFloat = 4
        static let tabUnderlineHeight: CGFloat = 3
        static let tabBottomPadding: CGFloat = 2
        static let minContentHeight: CGFloat = 120
    }
    
    // MARK: - Properties
    @StateObject private var viewModel: LMSHomeViewModel
    @Namespace private var tabBarNamespace
    
    // MARK: - Initialization
    init(viewModel: LMSHomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            VStack(spacing: 0) {
                header
                tabBar
                tabContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .ignoresSafeArea(.container, edges: .bottom)
            .sheet(isPresented: $viewModel.showMenu) {
                menuSheet
            }
            .alert("Cloud action triggered!", isPresented: $viewModel.showCloudAction) {
                Button("OK", role: .cancel) {}
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "createInspection" {
                    let createViewModel = CreateInspectionViewModel(createInspectionUseCase: Container.shared.resolve(CreateInspectionUseCase.self)!)
                    CreateInspectionView(viewModel: createViewModel) { createdInspection in
                        viewModel.handleNewInspectionCreated(createdInspection)
                    }
                }
            }
            .navigationDestination(for: Inspection.self) { inspection in
                InspectionDetailView(
                    inspectionId: inspection.id,
                    inspectionNumber: inspection.inspectionNumber
                )
            }
            .onChange(of: viewModel.navigationPath) { oldValue, newValue in
                viewModel.handleNavigationBack(from: oldValue, to: newValue)
            }
        }
    }
    
    // MARK: - Private Views
    private var header: some View {
        HStack {
            menuButton
            Spacer()
            LMSLabel("Kiểm tra", style: .title, alignment: .center)
            Spacer()
            cloudButton
        }
        .padding(.horizontal, Layout.headerHorizontalPadding)
        .padding(.vertical, Layout.headerVerticalPadding)
        .background(Color(.systemBackground))
        .shadow(
            color: Color(.black).opacity(Layout.shadowOpacity),
            radius: Layout.shadowRadius,
            y: Layout.shadowY
        )
    }
    
    private var menuButton: some View {
        LMSButton(
            "",
            icon: "line.3.horizontal",
            variant: .iconOnly,
            action: viewModel.showMenuAction
        )
        .frame(width: Layout.iconButtonSize, height: Layout.iconButtonSize)
    }
    
    private var cloudButton: some View {
        LMSButton(
            "",
            icon: "cloud",
            variant: .iconOnly,
            action: viewModel.triggerCloudAction
        )
        .frame(width: Layout.iconButtonSize, height: Layout.iconButtonSize)
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(LMSHomeViewModel.Tab.allCases, id: \.self) { tab in
                tabButton(for: tab)
            }
        }
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .bottom)
        .padding(.bottom, Layout.tabBottomPadding)
    }
    
    private func tabButton(for tab: LMSHomeViewModel.Tab) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                viewModel.selectedTab = tab
            }
        }) {
            tabButtonContent(for: tab)
        }
        .buttonStyle(.plain)
    }
    
    private func tabButtonContent(for tab: LMSHomeViewModel.Tab) -> some View {
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
            case .plan:
                PlanLMSHomeView(onQuickInspection: viewModel.navigateToCreateInspection)
            case .inProgress:
                inProgressContent
            case .report:
                reportContent
            }
        }
        .frame(maxWidth: .infinity, minHeight: Layout.minContentHeight)
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut, value: viewModel.selectedTab)
    }
    
    private var inProgressContent: some View {
        VStack {
            LMSLabel(
                "Nội dung Trong tiến trình",
                style: .body,
                alignment: .center
            )
        }
    }
    
    private var reportContent: some View {
        VStack {
            LMSLabel(
                "Nội dung Báo cáo",
                style: .body,
                alignment: .center
            )
        }
    }
    
    private var menuSheet: some View {
        VStack {
            LMSLabel(
                "Menu action triggered!",
                style: .title,
                alignment: .center
            )
            Spacer()
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    LMSHomeView(viewModel: LMSHomeViewModel())
}
