//
//  ErrorHomeView.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import SwiftUI

// MARK: - ErrorHomeView

struct ErrorHomeView: View {
    // MARK: - Constants
    private enum Layout {
        static let buttonSize: CGFloat = 56
        static let buttonBottomPadding: CGFloat = 32
        static let buttonTrailingPadding: CGFloat = 20
        static let buttonIconSize: CGFloat = 24
    }
    
    // MARK: - Properties
    @StateObject private var viewModel: ErrorHomeViewModel
    private let onNavigateToPhotoCaptureErrorReview: () -> Void
    
    // MARK: - Initialization
    init(viewModel: ErrorHomeViewModel, onNavigateToPhotoCaptureErrorReview: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onNavigateToPhotoCaptureErrorReview = onNavigateToPhotoCaptureErrorReview
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Group {
                if viewModel.errors.isEmpty {
                    EmptyErrorView()
                } else {
                    errorListView
                }
            }
            
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    reportButton
                        .padding(.trailing, Layout.buttonTrailingPadding)
                }
                .padding(.bottom, Layout.buttonBottomPadding)
            }
        }
        .task {
            await viewModel.loadErrors()
        }
    }
    
    // MARK: - Private Views
    private var errorListView: some View {
        List(viewModel.errors, id: \.self) { error in
            Text(error)
        }
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

#Preview("Empty State") {
    ErrorHomeView(
        viewModel: ErrorHomeViewModel(),
        onNavigateToPhotoCaptureErrorReview: {}
    )
}

#Preview("With Errors") {
    let viewModel = ErrorHomeViewModel()
    viewModel.errors = ["Error 1", "Error 2", "Error 3"]
    return ErrorHomeView(
        viewModel: viewModel,
        onNavigateToPhotoCaptureErrorReview: {}
    )
}

