//
//  LMSTextFieldStyle.swift
//  report_lms
//
//  Created by GitHub Copilot on 25/01/2026.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

struct LMSTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
    }
}

extension View {
    func lmsTextFieldStyle() -> some View {
        self.textFieldStyle(LMSTextFieldStyle())
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var text = ""
    return TextField("Placeholder", text: $text)
        .lmsTextFieldStyle()
        .padding()
}