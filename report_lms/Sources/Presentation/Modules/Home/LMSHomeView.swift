//
//  LMSHomeView.swift
//  report_lms
//
//  Created by AI on January 21, 2026.
//

import SwiftUI

// MARK: - LMSHomeView

struct LMSHomeView: View {
    // MARK: - Properties
    @StateObject private var viewModel: LMSHomeViewModel
    
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
                    let viewModel = CreateInspectionViewModel(createInspectionUseCase: Container.shared.resolve(CreateInspectionUseCase.self)!)
                    CreateInspectionView(viewModel: viewModel)
                }
            }
            .onChange(of: viewModel.navigationPath) { oldValue, newValue in
                viewModel.handleNavigationBack(from: oldValue, to: newValue)
            }
        }
    }
    
    // MARK: - Private Views
    private var header: some View {
        HStack {
            LMSButton("", icon: "line.3.horizontal", variant: .iconOnly, action: viewModel.showMenuAction)
                .frame(width: 44, height: 44)
            Spacer()
            LMSLabel("Kiểm tra", style: .title, alignment: .center)
            Spacer()
            LMSButton("", icon: "cloud", variant: .iconOnly, action: viewModel.triggerCloudAction)
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground))
        .shadow(color: Color(.black).opacity(0.04), radius: 2, y: 1)
    }
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(LMSHomeViewModel.Tab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(viewModel.selectedTab == tab ? .accentColor : .secondary)
                        LMSLabel(tab.title,
                                 style: .body,
                                 color: viewModel.selectedTab == tab ? .custom(Color.accentColor) : .secondary,
                                 alignment: .center)
                            .fontWeight(viewModel.selectedTab == tab ? .semibold : .regular)
                        ZStack {
                            if viewModel.selectedTab == tab {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(height: 3)
                                    .matchedGeometryEffect(id: "tabUnderline", in: tabBarNamespace)
                            } else {
                                Color.clear.frame(height: 3)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 0)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(.systemBackground))
        .overlay(Divider(), alignment: .bottom)
        .padding(.bottom, 2)
    }
    
    private var tabContent: some View {
        Group {
            switch viewModel.selectedTab {
            case .plan:
                PlanLMSHomeView(onQuickInspection: viewModel.navigateToCreateInspection)
            case .inProgress:
                VStack { LMSLabel("Nội dung Trong tiến trình", style: .body, alignment: .center) }
            case .report:
                VStack { LMSLabel("Nội dung Báo cáo", style: .body, alignment: .center) }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(Color(.systemGroupedBackground))
        .animation(.easeInOut, value: viewModel.selectedTab)
    }
    
    private var menuSheet: some View {
        VStack {
            LMSLabel("Menu action triggered!", style: .title, alignment: .center)
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Private Properties
    @Namespace private var tabBarNamespace
}

// MARK: - Preview

#Preview {
    LMSHomeView(viewModel: LMSHomeViewModel())
}
