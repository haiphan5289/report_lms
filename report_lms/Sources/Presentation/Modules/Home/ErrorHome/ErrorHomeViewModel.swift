//
//  ErrorHomeViewModel.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import SwiftUI

// MARK: - ErrorHomeViewModel

@MainActor
final class ErrorHomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var errors: [String] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Initialization
    init() {
        // Don't call async methods in init - let the View handle this
    }

    // MARK: - Public Methods
    func loadErrors() async {
        isLoading = true
        defer { isLoading = false }

        // Currently showing empty state - error fetching to be implemented
        errors = []
    }
}
