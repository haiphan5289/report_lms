//
//  LMSTextField.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

/// A reusable text field component with validation, icons, and helper text support
///
/// Example usage:
/// ```swift
/// @State private var email = ""
/// @State private var password = ""
///
/// LMSTextField(
///     "Email",
///     text: $email,
///     icon: "envelope",
///     keyboardType: .emailAddress
/// )
///
/// LMSTextField(
///     "Password",
///     text: $password,
///     icon: "lock",
///     isSecure: true,
///     validationState: email.isEmpty ? .normal : .success,
///     helperText: "Must be at least 8 characters"
/// )
/// ```
struct LMSTextField: View {
    // MARK: - Properties

    private let placeholder: String
    @Binding private var text: String
    private let icon: String?
    private let size: LMSTextFieldSize
    private let validationState: LMSTextFieldValidationState
    private let helperText: String?
    private let isSecure: Bool
    private let keyboardType: UIKeyboardType
    private let autocapitalization: TextInputAutocapitalization
    private let maxLength: Int?
    private let onCommit: (() -> Void)?

    @State private var isSecureVisible: Bool = false
    @FocusState private var isFocused: Bool

    // MARK: - Initialization

    /// Creates a text field with specified configuration
    /// - Parameters:
    ///   - placeholder: Placeholder text
    ///   - text: Binding to the text value
    ///   - icon: Optional SF Symbol icon name
    ///   - size: TextField size (default: .medium)
    ///   - validationState: Validation state (default: .normal)
    ///   - helperText: Optional helper or error text
    ///   - isSecure: Whether to hide text input (default: false)
    ///   - keyboardType: Keyboard type (default: .default)
    ///   - autocapitalization: Auto-capitalization behavior (default: .sentences)
    ///   - maxLength: Maximum character count (default: nil for unlimited)
    ///   - onCommit: Action to perform when return is pressed
    init(
        _ placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        size: LMSTextFieldSize = .medium,
        validationState: LMSTextFieldValidationState = .normal,
        helperText: String? = nil,
        isSecure: Bool = false,
        keyboardType: UIKeyboardType = .default,
        autocapitalization: TextInputAutocapitalization = .sentences,
        maxLength: Int? = nil,
        onCommit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.size = size
        self.validationState = validationState
        self.helperText = helperText
        self.isSecure = isSecure
        self.keyboardType = keyboardType
        self.autocapitalization = autocapitalization
        self.maxLength = maxLength
        self.onCommit = onCommit
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Text Field Container
            HStack(spacing: 12) {
                // Leading Icon
                if let icon = icon {
                    Image(systemName: icon)
                        .font(size.fontSize)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                }

                // Text Input
                textFieldView

                // Trailing Icons (Validation + Secure Toggle)
                HStack(spacing: 8) {
                    if let iconName = validationState.iconName {
                        Image(systemName: iconName)
                            .font(.body)
                            .foregroundColor(validationState.iconColor)
                    }

                    if isSecure {
                        Button(action: {
                            isSecureVisible.toggle()
                        }, label: {
                            Image(systemName: isSecureVisible ? "eye.slash.fill" : "eye.fill")
                                .font(.body)
                                .foregroundColor(.secondary)
                        })
                    }
                }
            }
            .padding(.horizontal, size.horizontalPadding)
            .frame(height: size.height)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.blue : validationState.borderColor, lineWidth: isFocused ? 2 : 1)
            )

            // Helper Text / Error Message
            if let helperText = helperText {
                HStack(spacing: 4) {
                    Text(helperText)
                        .font(.caption)
                        .foregroundColor(validationState == .error ? .red : .secondary)

                    Spacer()

                    // Character Counter
                    if let maxLength = maxLength {
                        Text("\(text.count)/\(maxLength)")
                            .font(.caption)
                            .foregroundColor(text.count > maxLength ? .red : .secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .animation(.easeInOut(duration: 0.2), value: validationState)
    }

    // MARK: - Private Views

    @ViewBuilder
    private var textFieldView: some View {
        if isSecure && !isSecureVisible {
            SecureField(placeholder, text: $text)
                .font(size.fontSize)
                .textInputAutocapitalization(autocapitalization)
                .keyboardType(keyboardType)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit {
                    onCommit?()
                }
                .onChange(of: text) { _, newValue in
                    if let maxLength = maxLength, newValue.count > maxLength {
                        text = String(newValue.prefix(maxLength))
                    }
                }
        } else {
            TextField(placeholder, text: $text)
                .font(size.fontSize)
                .textInputAutocapitalization(autocapitalization)
                .keyboardType(keyboardType)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit {
                    onCommit?()
                }
                .onChange(of: text) { _, newValue in
                    if let maxLength = maxLength, newValue.count > maxLength {
                        text = String(newValue.prefix(maxLength))
                    }
                }
        }
    }
}

// MARK: - Preview

#Preview("TextField Variants") {
    VStack(spacing: 20) {
        LMSTextField(
            "Email",
            text: .constant("user@example.com"),
            icon: "envelope",
            keyboardType: .emailAddress
        )

        LMSTextField(
            "Password",
            text: .constant("password123"),
            icon: "lock",
            isSecure: true
        )

        LMSTextField(
            "Username",
            text: .constant("johndoe"),
            icon: "person",
            validationState: .success,
            helperText: "Username is available"
        )

        LMSTextField(
            "Phone",
            text: .constant("123"),
            icon: "phone",
            validationState: .error,
            helperText: "Phone number is invalid"
        )
    }
    .padding()
}

#Preview("TextField Sizes") {
    VStack(spacing: 20) {
        LMSTextField(
            "Small Size",
            text: .constant("Text"),
            size: .small
        )

        LMSTextField(
            "Medium Size",
            text: .constant("Text"),
            size: .medium
        )

        LMSTextField(
            "Large Size",
            text: .constant("Text"),
            size: .large
        )
    }
    .padding()
}

#Preview("TextField States") {
    VStack(spacing: 20) {
        LMSTextField(
            "Normal State",
            text: .constant(""),
            icon: "text.cursor"
        )

        LMSTextField(
            "Success State",
            text: .constant("valid@email.com"),
            icon: "envelope",
            validationState: .success,
            helperText: "Email is valid"
        )

        LMSTextField(
            "Error State",
            text: .constant("invalid"),
            icon: "envelope",
            validationState: .error,
            helperText: "Email is invalid"
        )
    }
    .padding()
}

#Preview("TextField with Character Limit") {
    VStack(spacing: 20) {
        LMSTextField(
            "Username",
            text: .constant("john"),
            icon: "person",
            helperText: "Username must be unique",
            maxLength: 20
        )

        LMSTextField(
            "Bio",
            text: .constant("This is a long bio text"),
            icon: "text.alignleft",
            validationState: .normal,
            helperText: "Tell us about yourself",
            maxLength: 100
        )
    }
    .padding()
}

#Preview("Secure TextField") {
    VStack(spacing: 20) {
        LMSTextField(
            "Password",
            text: .constant("mypassword"),
            icon: "lock",
            helperText: "At least 8 characters", isSecure: true
        )

        LMSTextField(
            "Confirm Password",
            text: .constant("mypassword"),
            icon: "lock.fill",
            validationState: .success, helperText: "Passwords match", isSecure: true
        )
    }
    .padding()
}

#Preview("Dark Mode") {
    VStack(spacing: 20) {
        LMSTextField(
            "Email",
            text: .constant("user@example.com"),
            icon: "envelope"
        )

        LMSTextField(
            "Password",
            text: .constant("password"),
            icon: "lock",
            isSecure: true
        )

        LMSTextField(
            "Error",
            text: .constant("invalid"),
            validationState: .error,
            helperText: "This field has an error"
        )
    }
    .padding()
    .background(Color(.systemBackground))
    .preferredColorScheme(.dark)
}
