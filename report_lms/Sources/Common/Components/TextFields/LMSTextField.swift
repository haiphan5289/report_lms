//
//  LMSTextField.swift
//  report_lms
//
//  Created by GitHub Copilot on 25/01/2026.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

struct LMSTextField: View {
    // MARK: - Properties
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil

    // MARK: - Body
    var body: some View {
        HStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20, height: 20)
            }

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .lmsTextFieldStyle()
    }
}

// MARK: - Preview
#Preview("Default") {
    @Previewable @State var text = ""
    LMSTextField(placeholder: "Enter text", text: $text)
}

#Preview("With Icon") {
    @Previewable @State var text = ""
    LMSTextField(placeholder: "Search...", text: $text, icon: "magnifyingglass")
}