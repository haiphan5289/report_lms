//
//  LMSHomeViewModel.swift
//  report_lms
//
//  Created by AI on January 25, 2026.
//

import SwiftUI

// MARK: - LMSHomeViewModel

final class LMSHomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var showMenu = false
    @Published var showCloudAction = false
    @Published var selectedTab: Tab = .plan
    @Published var navigationPath = NavigationPath()

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

    func navigateToPhotoCaptureErrorReview() {
        navigationPath.append("photoCaptureErrorReview")
    }

    func handleNewInspectionCreated(_ inspection: Inspection) {
        // Handle the new inspection creation
        // You can add it to a list or trigger a refresh
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
            case .inProgress: return "Lỗi"
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
