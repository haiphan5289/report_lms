//
//  LMSHomeView.swift
//  report_lms
//
//  Created by AI on January 21, 2026.
//

import SwiftUI

// MARK: - LMSHomeView

struct LMSHomeView: View {

    // MARK: - Layout Constants

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
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Namespace private var tabBarNamespace
    let onLogout: () -> Void

    // Animation
    @State private var headerVisible = false
    @State private var tabBarVisible = false

    // MARK: - Initialization

    init(viewModel: LMSHomeViewModel, onLogout: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onLogout = onLogout
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Main content
            NavigationStack(path: $viewModel.navigationPath) {
                VStack(spacing: 0) {
                    header
                    tabBar
                    tabContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
                .ignoresSafeArea(.container, edges: .bottom)
                .alert(localizationManager.localize("home.alert.cloudAction"), isPresented: $viewModel.showCloudAction) {
                    Button(localizationManager.localize("common.ok"), role: .cancel) {}
                }
                .navigationDestination(for: String.self) { destination in
                    switch destination {
                    case "createInspection":
                        CreateInspectionDestination { createdInspection in
                            viewModel.handleNewInspectionCreated(createdInspection)
                        }
                    case "orders":
                        OrdersView()
                    case "profile":
                        Text("Profile")
                            .navigationTitle("Profile")
                    case "settings":
                        SettingsView()
                    case "sendEmailList":
                        SendEmailListDestination()
                    default:
                        EmptyView()
                    }
                }
                .navigationDestination(for: Inspection.self) { inspection in
                    InspectionDetailView(
                        inspectionId: inspection.id,
                        inspectionNumber: inspection.inspectionNumber,
                        homeViewModel: viewModel
                    )
                }
                .onChange(of: viewModel.navigationPath) { oldValue, newValue in
                    viewModel.handleNavigationBack(from: oldValue, to: newValue)
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 0.4)) { headerVisible = true }
                    withAnimation(.easeOut(duration: 0.4).delay(0.1)) { tabBarVisible = true }
                }
            }

            // Side menu overlay
            if viewModel.showMenu {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.showMenu = false
                        }
                    }

                HStack {
                    MenuView { action in
                        switch action {
                        case .profile:
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.navigateToProfile()
                            }
                        case .settings:
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.navigateToSettings()
                            }
                        case .orders:
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.navigateToOrders()
                            }
                        case .sendEmailList:
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.showMenu = false
                            }
                            viewModel.navigationPath.append("sendEmailList")
                        case .logout:
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.showMenu = false
                            }
                            onLogout()
                        }
                    }
                    .frame(width: 300)
                    .background(Color(.systemBackground))
                    .transition(.move(edge: .leading))
                    .zIndex(1)

                    Spacer()
                }
                .transition(.move(edge: .leading))
                .zIndex(2)
            }
        }
    }

    // MARK: - Private Views

    private var header: some View {
        HStack {
            menuButton
            Spacer()
            LMSLabel(localizationManager.localize("home.title"), style: .title, alignment: .center)
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
        .opacity(headerVisible ? 1 : 0)
        .offset(y: headerVisible ? 0 : -12)
        .animation(.easeOut(duration: 0.4), value: headerVisible)
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
        .opacity(tabBarVisible ? 1 : 0)
    }

    private func tabButton(for tab: LMSHomeViewModel.Tab) -> some View {
        Button(action: {
            viewModel.selectedTab = tab
        }, label: {
            tabButtonContent(for: tab)
        })
        .buttonStyle(.plain)
    }

    private func tabButtonContent(for tab: LMSHomeViewModel.Tab) -> some View {
        let isSelected = viewModel.selectedTab == tab

        return VStack(spacing: Layout.tabSpacing) {
            Image(systemName: tab.icon)
                .font(.system(size: Layout.tabIconSize, weight: .semibold))
                .foregroundColor(isSelected ? .accentColor : .secondary)

            LMSLabel(
                localizationManager.localize(tab.title),
                style: .subheadline,
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
                PlanLMSHomeView(
                    refreshTrigger: viewModel.dataRefreshTrigger,
                    onQuickInspection: viewModel.navigateToCreateInspection,
                    onInspectionTapped: viewModel.navigateToInspectionDetail
                )
            case .inProgress:
                LMSProgressView(onInspectionTapped: viewModel.navigateToInspectionDetail)
            case .report:
                reportContent
            }
        }
        .frame(maxWidth: .infinity, minHeight: Layout.minContentHeight)
        .background(Color(.systemGroupedBackground))
    }

    private var reportContent: some View {
        ReportLMSHomeView(scrollToInspectionId: $viewModel.scrollToInspectionId)
    }
}

// MARK: - SendEmailListDestination

private struct SendEmailListDestination: View {
    @StateObject private var viewModel: SendEmailListViewModel

    init() {
        guard let queueService = Container.shared.resolve(ReportDeliveryQueueService.self) else {
            fatalError("ReportDeliveryQueueService not registered in DI container")
        }
        _viewModel = StateObject(wrappedValue: SendEmailListViewModel(queueService: queueService))
    }

    var body: some View {
        SendEmailListView(viewModel: viewModel)
    }
}

// MARK: - CreateInspectionDestination

private struct CreateInspectionDestination: View {
    @StateObject private var viewModel: CreateInspectionViewModel
    let onCreated: (Inspection) -> Void

    init(onCreated: @escaping (Inspection) -> Void) {
        self.onCreated = onCreated
        guard let useCase = Container.shared.resolve(CreateInspectionUseCase.self),
              let storage = Container.shared.resolve(InspectionStorageServiceType.self) else {
            fatalError("CreateInspectionUseCase or InspectionStorageServiceType not registered in DI container")
        }
        _viewModel = StateObject(wrappedValue: CreateInspectionViewModel(
            createInspectionUseCase: useCase,
            storageService: storage
        ))
    }

    var body: some View {
        CreateInspectionView(viewModel: viewModel) { createdInspection in
            onCreated(createdInspection)
        }
    }
}

// MARK: - Preview

#Preview {
    LMSHomeView(viewModel: LMSHomeViewModel(), onLogout: {})
        .environmentObject(LocalizationManager.shared)
}
