//
//  ErrorHomeView.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import SwiftUI

// MARK: - ErrorHomeView

struct ErrorHomeView: View {
    private enum Layout {
        static let buttonSize: CGFloat = 56
        static let buttonBottomPadding: CGFloat = 32
        static let buttonTrailingPadding: CGFloat = 20
        static let buttonIconSize: CGFloat = 24
    }

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
        ZStack {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.errors.isEmpty {
                EmptyErrorView()
            } else {
                // TODO: Implement error list view when errors are available
                EmptyErrorView()
            }
            containerButton
        }
        .task {
            await viewModel.loadErrors()
        }
    }
    
    private var containerButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                reportButton
                    .padding(.trailing, Layout.buttonTrailingPadding)
            }
            .padding()
        }
        .padding(.bottom, Layout.buttonBottomPadding)
    }
    
    private var reportButton: some View {
        Button(action: handleReportError) {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: Layout.buttonSize, height: Layout.buttonSize)
                    .shadow(color: Color.red.opacity(0.3), radius: 8, y: 4)
                
                Image(systemName: "exclamationmark")
                    .font(.system(size: Layout.buttonIconSize, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Private Methods
    private func handleReportError() {
        onNavigateToPhotoCaptureErrorReview()
    }

}

// MARK: - Preview

#Preview("Error Home View") {
    ErrorHomeView(
        viewModel: ErrorHomeViewModel(),
        onNavigateToPhotoCaptureErrorReview: {}
    )
}
