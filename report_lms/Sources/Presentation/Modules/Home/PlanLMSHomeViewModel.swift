//
//  PlanLMSHomeViewModel.swift
//  report_lms
//
//  Created by AI on January 25, 2026.
//

import SwiftUI

// MARK: - PlanLMSHomeViewModel

@MainActor
final class PlanLMSHomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var showSheet = false
    @Published var navigationPath = NavigationPath()
    
    // MARK: - Private Properties
    private let onQuickInspection: () -> Void
    
    // MARK: - Initialization
    init(onQuickInspection: @escaping () -> Void) {
        self.onQuickInspection = onQuickInspection
    }
    
    // MARK: - Public Methods
    func showFloatingButtonAction() {
        showSheet = true
    }
    
    func handleQuickInspection() {
        showSheet = false
        onQuickInspection()
    }
}