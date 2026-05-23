//
//  LMSColor.swift
//  report_lms
//
//  Created by AI on February 7, 2026.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

/// Centralized color system for the LMS app
/// Provides semantic color constants for consistent theming across the application
struct LMSColor {
        // MARK: - Control Colors

        /// Adaptive background for controls (e.g., camera controls)
        static var controlBackground: Color {
            Color("ControlBackground", bundle: .main)
        }

        /// Adaptive foreground for controls (text/icons)
        static var controlForeground: Color {
            Color("ControlForeground", bundle: .main)
        }
    // MARK: - Primary Colors

    /// Primary brand color - used for main actions and highlights
    static let primary = Color.blue

    /// Primary color with opacity for subtle backgrounds
    static let primaryLight = Color.blue.opacity(0.1)

    /// Primary color for borders and outlines
    static let primaryBorder = Color.blue.opacity(0.3)

    // MARK: - Secondary Colors

    /// Secondary color for less prominent UI elements
    static let secondary = Color(.systemGray4)

    /// Secondary color for subtle backgrounds
    static let secondaryBackground = Color(.systemGray5)

    /// Secondary color for borders
    static let secondaryBorder = Color.secondary.opacity(0.2)

    // MARK: - Destructive Colors

    /// Color for destructive actions (delete, remove, etc.)
    static let destructive = Color.red
    
    // MARK: - Status Colors
    
    /// Color for success states and positive feedback
    static let success = Color.green
    
    /// Color for warnings and attention-requiring elements
    static let warning = Color.orange

    // MARK: - Neutral Colors

    /// Ghost/transparent color for subtle interactions
    static let ghost = Color.clear

    // MARK: - Shadow Colors

    /// Shadow color that adapts to light/dark mode
    static let shadow = Color(.label).opacity(0.1)

    /// Stronger shadow for prominent elements
    static let shadowStrong = Color(.label).opacity(0.15)

    // MARK: - Background Colors

    /// System background color
    static let background = Color(.systemBackground)

    /// Secondary background color
    static let backgroundSecondary = Color(.systemGray6)

    /// Grouped background color
    static let backgroundGrouped = Color(.systemGroupedBackground)

    // MARK: - Text Colors

    /// Primary text color
    static let textPrimary = Color.primary

    /// Secondary text color
    static let textSecondary = Color.secondary

    /// Tertiary text color
    static let textTertiary = Color(.systemGray)

    // MARK: - Utility Colors

    /// White color
    static let white = Color.white

    /// Black color
    static let black = Color.black

    /// Clear color
    static let clear = Color.clear
}

// MARK: - Semantic Color Extensions

extension LMSColor {
    /// Colors for button variants
    struct Button {
        static let primaryBackground = LMSColor.primary
        static let primaryForeground = LMSColor.white

        static let secondaryBackground = LMSColor.secondary
        static let secondaryForeground = LMSColor.textPrimary

        static let tertiaryBackground = LMSColor.secondaryBackground
        static let tertiaryForeground = LMSColor.textPrimary
        static let tertiaryBorder = LMSColor.secondary

        static let destructiveBackground = LMSColor.destructive
        static let destructiveForeground = LMSColor.white

        static let ghostBackground = LMSColor.ghost
        static let ghostForeground = LMSColor.primary

        static let iconOnlyForeground = LMSColor.textPrimary
    }

    /// Colors for shadows and depth
    struct Shadow {
        static let subtle = LMSColor.shadow
        static let medium = LMSColor.shadowStrong
        static let strong = Color.black.opacity(0.2)
    }

    /// Colors for borders and outlines
    struct Border {
        static let subtle = LMSColor.secondaryBorder
        static let medium = Color.secondary.opacity(0.3)
        static let strong = Color.secondary.opacity(0.5)
    }
}