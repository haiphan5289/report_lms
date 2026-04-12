//
//  LMSHomeViewModel.swift
//  report_lms
//
//  Created by AI on January 25, 2026.
//

import SwiftUI
import Combine

// MARK: - LMSHomeViewModel

final class LMSHomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var showMenu = false
    @Published var showCloudAction = false
    @Published var selectedTab: Tab = .plan
    @Published var navigationPath = NavigationPath()
    @Published var dataRefreshTrigger = 0
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupNotificationObservers()
    }
    
    // MARK: - Private Methods
    private func setupNotificationObservers() {
        // No active observers
    }

    // MARK: - Public Methods
    func showMenuAction() {
        showMenu = true
    }

    func triggerCloudAction() {
        showCloudAction = true
    }

    func navigateToCreateInspection() {
        navigationPath.append("createInspection")
    }

    func navigateToInspectionDetail(_ inspection: Inspection) {
        navigationPath.append(inspection)
    }

    func navigateToProfile() {
        showMenu = false
        navigationPath.append("profile")
    }

    func navigateToSettings() {
        showMenu = false
        navigationPath.append("settings")
    }

    func navigateToOrders() {
        showMenu = false
        navigationPath.append("orders")
    }

    func handleNewInspectionCreated(_ inspection: Inspection) {
        // Trigger data refresh in Plan tab
        dataRefreshTrigger += 1
    }
    
    func navigateToReportTab() {
        // Pop back to home by clearing navigation path
        navigationPath = NavigationPath()
        
        // Switch to report tab (which shows InformationPurchaseView)
        selectedTab = .report
    }

    func handleNavigationBack(from oldValue: NavigationPath, to newValue: NavigationPath) {
        // Handle navigation back event
        if oldValue.count > newValue.count {
            // User navigated back to LMSHome
            handleNavigationBack()
        }
    }

    // MARK: - Private Methods
    private func handleNavigationBack() {
        // Handle event when user navigates back to LMSHome
        // You can add any logic here when navigation comes back
        // For example: refresh data, show success message, update UI state, etc.

        // Example: Switch to a specific tab or show a toast message
        // selectedTab = .report

        // Example: Show success feedback
        // showSuccessMessage = true
    }
}

// MARK: - Tab Enum

extension LMSHomeViewModel {
    enum Tab: Int, CaseIterable {
        case plan, inProgress, report

        var title: String {
            switch self {
            case .plan: return "Kế hoạch"
            case .inProgress: return "Trong tiến trình"
            case .report: return "Báo cáo"
            }
        }

        var icon: String {
            switch self {
            case .plan: return "calendar"
            case .inProgress: return "clock.arrow.circlepath"
            case .report: return "doc.text.magnifyingglass"
            }
        }
    }
}
