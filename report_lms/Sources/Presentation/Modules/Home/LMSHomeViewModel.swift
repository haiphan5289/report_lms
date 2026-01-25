//
//  LMSHomeViewModel.swift
//  report_lms
//
//  Created by AI on January 25, 2026.
//

import SwiftUI

// MARK: - LMSHomeViewModel

@MainActor
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
        print("User navigated back to LMSHome")
        
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