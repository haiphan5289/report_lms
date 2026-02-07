//
//  ErrorHomeView.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import SwiftUI
import UIKit

// MARK: - Layout Constants
private enum ErrorHomeLayout {
    static let buttonSize: CGFloat = 56
    static let buttonBottomPadding: CGFloat = 32
    static let buttonTrailingPadding: CGFloat = 20
    static let buttonIconSize: CGFloat = 24
}

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
        ZStack {
            if viewModel.isLoading {
                LMSLoadingView(message: "Đang tải danh sách lỗi...")
            } else if viewModel.errors.isEmpty {
                EmptyErrorView()
            } else {
                errorListView
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
                    .padding(.trailing, ErrorHomeLayout.buttonTrailingPadding)
            }
            .padding()
        }
        .padding(.bottom, ErrorHomeLayout.buttonBottomPadding)
    }
    
    private var errorListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(viewModel.errors) { error in
                    ErrorListItemView(error: error)
                }
            }
            .padding()
        }
    }
    
    private var reportButton: some View {
        Button(action: handleReportError) {
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: ErrorHomeLayout.buttonSize, height: ErrorHomeLayout.buttonSize)
                    .shadow(color: Color.red.opacity(0.3), radius: 8, y: 4)
                
                Image(systemName: "exclamationmark")
                    .font(.system(size: ErrorHomeLayout.buttonIconSize, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }
    
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
