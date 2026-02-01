//
//  LMSLoadingView.swift
//  report_lms
//
//  Created by GitHub Copilot on 1/2/26.
//

import SwiftUI

/// Inline loading view for initial data loads and empty states
/// Non-blocking, center-positioned loading indicator
struct LMSLoadingView: View {
    // MARK: - Properties
    let message: String
    
    // MARK: - Initialization
    init(message: String = "Đang tải...") {
        self.message = message
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.primary)
            
            LMSLabel(
                message,
                style: .body,
                color: .secondary
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview
#Preview("Default") {
    LMSLoadingView()
}

#Preview("Custom Message") {
    LMSLoadingView(message: "Đang xử lý...")
}

#Preview("In List Context") {
    NavigationStack {
        LMSLoadingView(message: "Đang tải danh sách...")
            .navigationTitle("Danh sách")
    }
}
