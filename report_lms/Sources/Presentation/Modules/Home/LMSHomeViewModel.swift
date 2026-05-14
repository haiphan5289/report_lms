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
        dataRefreshTrigger += 1
    }

    func navigateToReportTab() {
        navigationPath = NavigationPath()
        selectedTab = .report
    }

    func handleNavigationBack(from oldValue: NavigationPath, to newValue: NavigationPath) {
        // Reserved for back-navigation side-effects (e.g. refresh, snackbar)
    }
}

// MARK: - Tab Enum

extension LMSHomeViewModel {
    enum Tab: Int, CaseIterable {
        case plan, inProgress, report

        var title: String {
            switch self {
            case .plan: return "home.tab.plan"
            case .inProgress: return "home.tab.inProgress"
            case .report: return "home.tab.report"
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
