//
//  LMSLabel.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

/// A reusable text label component with standardized typography and styling
///
/// Example usage:
/// ```swift
/// LMSLabel("Welcome to LMS", style: .title)
/// LMSLabel("Report Description", style: .body, color: .secondary)
/// LMSLabel("Error message", style: .caption, color: .error)
/// ```
struct LMSLabel: View {
    // MARK: - Properties

    private let text: String
    private let style: LMSTextStyle
    private let color: LMSTextColor
    private let alignment: TextAlignment
    private let lineLimit: Int?
    private let accessibilityLabel: String?

    // MARK: - Initialization

    /// Creates a text label with specified style and color
    /// - Parameters:
    ///   - text: The text content to display
    ///   - style: The typography style (default: .body)
    ///   - color: The text color (default: .primary)
    ///   - alignment: Text alignment (default: .leading)
    ///   - lineLimit: Maximum number of lines (default: nil for unlimited)
    ///   - accessibilityLabel: Custom accessibility label (default: uses text)
    init(
        _ text: String,
        style: LMSTextStyle = .body,
        color: LMSTextColor = .primary,
        alignment: TextAlignment = .leading,
        lineLimit: Int? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.text = text
        self.style = style
        self.color = color
        self.alignment = alignment
        self.lineLimit = lineLimit
        self.accessibilityLabel = accessibilityLabel
    }

    // MARK: - Body

    var body: some View {
        Text(text)
            .font(style.font)
            .fontWeight(style.weight)
            .foregroundColor(color.color)
            .multilineTextAlignment(alignment)
            .lineLimit(lineLimit)
            .accessibilityLabel(accessibilityLabel ?? text)
    }
}

// MARK: - View Extensions

extension LMSLabel {
    /// Sets a custom font weight
    func fontWeight(_ weight: Font.Weight) -> some View {
        Text(text)
            .font(style.font)
            .fontWeight(weight)
            .foregroundColor(color.color)
            .multilineTextAlignment(alignment)
            .lineLimit(lineLimit)
    }
}

// MARK: - Preview

#Preview("Text Styles") {
    VStack(alignment: .leading, spacing: 16) {
        LMSLabel("Large Title", style: .largeTitle)
        LMSLabel("Title", style: .title)
        LMSLabel("Title 2", style: .title2)
        LMSLabel("Title 3", style: .title3)
        LMSLabel("Headline", style: .headline)
        LMSLabel("Subheadline", style: .subheadline)
        LMSLabel("Body Text", style: .body)
        LMSLabel("Callout", style: .callout)
        LMSLabel("Footnote", style: .footnote)
        LMSLabel("Caption", style: .caption)
        LMSLabel("Caption 2", style: .caption2)
    }
    .padding()
}

#Preview("Text Colors") {
    VStack(alignment: .leading, spacing: 16) {
        LMSLabel("Primary Color", style: .body, color: .primary)
        LMSLabel("Secondary Color", style: .body, color: .secondary)
        LMSLabel("Tertiary Color", style: .body, color: .tertiary)
        LMSLabel("Success Color", style: .body, color: .success)
        LMSLabel("Warning Color", style: .body, color: .warning)
        LMSLabel("Error Color", style: .body, color: .error)
        LMSLabel("Custom Color", style: .body, color: .custom(.blue))
    }
    .padding()
}

#Preview("Dark Mode") {
    VStack(alignment: .leading, spacing: 16) {
        LMSLabel("Primary in Dark Mode", style: .headline, color: .primary)
        LMSLabel("Secondary in Dark Mode", style: .body, color: .secondary)
        LMSLabel("Error in Dark Mode", style: .body, color: .error)
    }
    .padding()
    .background(Color(.systemBackground))
    .preferredColorScheme(.dark)
}

#Preview("Multiline Text") {
    VStack(alignment: .leading, spacing: 16) {
        LMSLabel(
            "This is a very long text that will wrap to multiple lines to demonstrate " +
            "the multiline text alignment and line limit features.",
            style: .body,
            lineLimit: 2
        )

        LMSLabel(
            "Center aligned multiline text that demonstrates the alignment property working correctly.",
            style: .body,
            alignment: .center
        )

        LMSLabel(
            "Trailing aligned text",
            style: .caption,
            color: .secondary,
            alignment: .trailing
        )
    }
    .padding()
}
