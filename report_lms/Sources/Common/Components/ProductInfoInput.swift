//
//  ProductInfoInput.swift
//  report_lms
//
//  Created by GitHub Copilot on 22/01/2026.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

enum ProductInfoInputType {
    case normal
    case required
    case dropdown
    case quantity
}

struct ProductInfoInput: View {
    // MARK: - Properties
    let title: String
    @Binding var text: String
    let type: ProductInfoInputType
    var dropdownOptions: [String] = []
    var onDropdownTap: (() -> Void)?
    var errorMessage: String?

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title + (type == .required ? " *" : ""))
                .font(.headline)
            inputField
            if let errorToShow = errorToShow {
                LMSLabel(errorToShow, style: .caption, color: .error)
            }
        }
    }

    // MARK: - Computed Properties
    private var errorToShow: String? {
        return errorMessage
    }

    @ViewBuilder
    private var inputField: some View {
        let baseTextField = TextField("", text: $text)
            .textFieldStyle(.roundedBorder)

        switch type {
        case .normal:
            baseTextField
        case .required:
            baseTextField
        case .dropdown:
            baseTextField
                .disabled(true)
                .overlay(
                    HStack {
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                        .padding()
                )
                .contentShape(Rectangle())
                .onTapGesture {

                    onDropdownTap?()
                }
        case .quantity:
            baseTextField
        }
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var requiredText = ""

    return VStack(spacing: 24) {
        ProductInfoInput(
            title: "Normal Input",
            text: .constant(""),
            type: .normal
        )
        ProductInfoInput(
            title: "Required Input (shows error when errorMessage is provided)",
            text: $requiredText,
            type: .required,
            errorMessage: "This field is required"
        )
        ProductInfoInput(
            title: "Required Input with Text (no error shown)",
            text: .constant("Some text"),
            type: .required
        )
        ProductInfoInput(
            title: "Dropdown Input",
            text: .constant("Select type"),
            type: .dropdown,
            dropdownOptions: ["Type A", "Type B"],
            onDropdownTap: { print("Dropdown tapped") }
        )
    }
    .padding()
}
