//
//  LMSTextStyle.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

/// Text style variants for consistent typography across the app
enum LMSTextStyle {
    case largeTitle
    case title
    case title2
    case title3
    case headline
    case subheadline
    case body
    case callout
    case footnote
    case caption
    case caption2
    
    var font: Font {
        switch self {
        case .largeTitle:
            return .largeTitle
        case .title:
            return .title
        case .title2:
            return .title2
        case .title3:
            return .title3
        case .headline:
            return .headline
        case .subheadline:
            return .subheadline
        case .body:
            return .body
        case .callout:
            return .callout
        case .footnote:
            return .footnote
        case .caption:
            return .caption
        case .caption2:
            return .caption2
        }
    }
    
    var weight: Font.Weight {
        switch self {
        case .largeTitle, .title, .title2, .title3, .headline:
            return .bold
        case .subheadline, .callout:
            return .semibold
        case .body, .footnote, .caption, .caption2:
            return .regular
        }
    }
}

/// Color style variants for text
enum LMSTextColor {
    case primary
    case secondary
    case tertiary
    case success
    case warning
    case error
    case custom(Color)
    
    var color: Color {
        switch self {
        case .primary:
            return .primary
        case .secondary:
            return .secondary
        case .tertiary:
            return Color(.tertiaryLabel)
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        case .custom(let color):
            return color
        }
    }
}
