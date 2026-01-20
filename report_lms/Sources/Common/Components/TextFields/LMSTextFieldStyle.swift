//
//  LMSTextFieldStyle.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

/// TextField validation state
enum LMSTextFieldValidationState {
    case normal
    case success
    case error
    
    var borderColor: Color {
        switch self {
        case .normal:
            return Color(.systemGray4)
        case .success:
            return .green
        case .error:
            return .red
        }
    }
    
    var iconName: String? {
        switch self {
        case .normal:
            return nil
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .normal:
            return .clear
        case .success:
            return .green
        case .error:
            return .red
        }
    }
}

/// TextField size variants
enum LMSTextFieldSize {
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
    
    var fontSize: Font {
        switch self {
        case .small:
            return .subheadline
        case .medium:
            return .body
        case .large:
            return .body
        }
    }
    
    var horizontalPadding: CGFloat {
        switch self {
        case .small:
            return 12
        case .medium:
            return 16
        case .large:
            return 20
        }
    }
}
