//
//  ErrorHomeView.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import SwiftUI

// MARK: - ErrorHomeView

struct ErrorHomeView: View {
    // MARK: - Properties
    @StateObject private var viewModel: ErrorHomeViewModel
    var onNavigateToPhotoCaptureErrorReview: () -> Void

    // MARK: - Initialization
    init(viewModel: ErrorHomeViewModel, onNavigateToPhotoCaptureErrorReview: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onNavigateToPhotoCaptureErrorReview = onNavigateToPhotoCaptureErrorReview
    }

    // MARK: - Body
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.errors.isEmpty {
                EmptyErrorView()
            } else {
                // TODO: Implement error list view when errors are available
                EmptyErrorView()
            }
        }
        .task {
            await viewModel.loadErrors()
        }
    }
}

// MARK: - Preview

#Preview("Error Home View") {
    ErrorHomeView(
        viewModel: ErrorHomeViewModel(),
        onNavigateToPhotoCaptureErrorReview: {}
    )
}
