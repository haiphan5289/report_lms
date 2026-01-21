//
//  LMSButtonStyle.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

/// Button style variants for different use cases
enum LMSButtonVariant {
    case primary
    case secondary
    case tertiary
    case destructive
    case ghost
    case iconOnly
    
    var backgroundColor: Color {
        switch self {
        case .primary:
            return .blue
        case .secondary:
            return Color(.systemGray5)
        case .tertiary:
            return .clear
        case .destructive:
            return .red
        case .ghost, .iconOnly:
            return .clear
        }
    }
    
    var foregroundColor: Color {
        switch self {
        case .primary, .destructive:
            return .white
        case .secondary:
            return .primary
        case .tertiary, .ghost, .iconOnly:
            return .blue
        }
    }
    
    var borderColor: Color? {
        switch self {
        case .tertiary:
            return .blue
        case .ghost:
            return Color(.systemGray4)
        default:
            return nil
        }
    }
}

/// Button size variants
enum LMSButtonSize {
    case small
    case medium
    case large
    
    var height: CGFloat {
        switch self {
        case .small:
            return 36
        case .medium:
            return 44
        case .large:
            return 52
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small:
            return 16
        case .medium:
            return 20
        case .large:
            return 24
        }
    }
    
    var fontSize: Font {
        switch self {
        case .small:
            return .subheadline
        case .medium:
            return .body
        case .large:
            return .headline
        }
    }
}
