//
//  QuantityInputView.swift
//  report_lms
//
//  Created by GitHub Copilot on 25/01/2026.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

struct QuantityInputView: View {
    // MARK: - Properties
    let labelText: String
    let placeholder: String
    @Binding var text: String
    var spacing: CGFloat = 16
    var containerPadding: CGFloat = 16
    var showContainerBackground: Bool = true

    // MARK: - Body
    var body: some View {
        HStack(spacing: spacing) {
            LMSLabel(labelText, style: .headline, color: .primary)
            Spacer()
            LMSTextField(placeholder, text: $text)
                .frame(maxWidth: 200)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, containerPadding)
        .padding(.vertical, 8)
        .background(showContainerBackground ? Color(.systemGray6) : Color.clear)
        .cornerRadius(showContainerBackground ? 8 : 0)
    }
}

// MARK: - Preview
#Preview("Default") {
    @Previewable @State var text = ""
    return QuantityInputView(
        labelText: "Quantity",
        placeholder: "Enter quantity",
        text: $text
    )
}
