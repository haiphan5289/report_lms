//
//  LMSButton.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

/// A reusable button component with multiple style variants and loading state support
///
/// Example usage:
/// ```swift
/// LMSButton("Submit", variant: .primary) {
///     print("Button tapped")
/// }
///
/// LMSButton("Cancel", variant: .secondary, size: .small) {
///     dismiss()
/// }
///
/// LMSButton("Delete", variant: .destructive, isLoading: $isDeleting) {
///     await deleteItem()
/// }
/// ```
struct LMSButton: View {
    // MARK: - Properties
    
    private let title: String
    private let icon: String?
    private let variant: LMSButtonVariant
    private let size: LMSButtonSize
    private let isFullWidth: Bool
    @Binding private var isLoading: Bool
    private let isDisabled: Bool
    private let action: () -> Void
    
    // MARK: - Initialization
    
    /// Creates a button with specified style and action
    /// - Parameters:
    ///   - title: The button label text
    ///   - icon: Optional SF Symbol icon name
    ///   - variant: The button style variant (default: .primary)
    ///   - size: The button size (default: .medium)
    ///   - isFullWidth: Whether button should expand to fill available width (default: false)
    ///   - isLoading: Binding to control loading state (default: false)
    ///   - isDisabled: Whether button is disabled (default: false)
    ///   - action: Action to perform when button is tapped
    init(
        _ title: String,
        icon: String? = nil,
        variant: LMSButtonVariant = .primary,
        size: LMSButtonSize = .medium,
        isFullWidth: Bool = false,
        isLoading: Binding<Bool> = .constant(false),
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.variant = variant
        self.size = size
        self.isFullWidth = isFullWidth
        self._isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: {
            guard !isLoading && !isDisabled else { return }
            action()
        }) {
            contentView
        }
        .buttonStyle(LMSButtonPressableStyle())
        .disabled(isDisabled || isLoading)
        .opacity((isDisabled || isLoading) ? 0.6 : 1.0)
        .accessibilityLabel(title)
        .accessibilityHint(isLoading ? "Loading" : "")
        .accessibilityAddTraits(isDisabled ? .isButton : [.isButton])
    }
    
    // MARK: - Private Views
    
    private var contentView: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(variant.foregroundColor)
                    .scaleEffect(0.9)
            } else {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(size.fontSize)
                }
                
                Text(title)
                    .font(size.fontSize)
                    .fontWeight(.semibold)
            }
        }
        .foregroundColor(variant.foregroundColor)
        .frame(maxWidth: isFullWidth ? .infinity : nil)
        .frame(height: size.height)
        .padding(.horizontal, size.horizontalPadding)
        .background(variant.backgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(variant.borderColor ?? .clear, lineWidth: 1)
        )
    }
}

// MARK: - Custom Button Style

struct LMSButtonPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Button Variants") {
    VStack(spacing: 16) {
        LMSButton("Primary Button", variant: .primary) {
            print("Primary tapped")
        }
        
        LMSButton("Secondary Button", variant: .secondary) {
            print("Secondary tapped")
        }
        
        LMSButton("Tertiary Button", variant: .tertiary) {
            print("Tertiary tapped")
        }
        
        LMSButton("Destructive Button", variant: .destructive) {
            print("Destructive tapped")
        }
        
        LMSButton("Ghost Button", variant: .ghost) {
            print("Ghost tapped")
        }
    }
    .padding()
}

#Preview("Button Sizes") {
    VStack(spacing: 16) {
        LMSButton("Small Button", size: .small) {
            print("Small tapped")
        }
        
        LMSButton("Medium Button", size: .medium) {
            print("Medium tapped")
        }
        
        LMSButton("Large Button", size: .large) {
            print("Large tapped")
        }
    }
    .padding()
}

#Preview("Button with Icons") {
    VStack(spacing: 16) {
        LMSButton("Add Item", icon: "plus", variant: .primary) {
            print("Add tapped")
        }
        
        LMSButton("Delete", icon: "trash", variant: .destructive) {
            print("Delete tapped")
        }
        
        LMSButton("Settings", icon: "gear", variant: .secondary) {
            print("Settings tapped")
        }
    }
    .padding()
}

#Preview("Button States") {
    VStack(spacing: 16) {
        LMSButton("Normal Button", variant: .primary) {
            print("Normal tapped")
        }
        
        LMSButton(
            "Loading Button",
            variant: .primary,
            isLoading: .constant(true)
        ) {
            print("Loading tapped")
        }
        
        LMSButton(
            "Disabled Button",
            variant: .primary,
            isDisabled: true
        ) {
            print("Disabled tapped")
        }
    }
    .padding()
}

#Preview("Full Width Buttons") {
    VStack(spacing: 16) {
        LMSButton("Full Width Primary", variant: .primary, isFullWidth: true) {
            print("Full width tapped")
        }
        
        LMSButton("Full Width Secondary", variant: .secondary, isFullWidth: true) {
            print("Full width tapped")
        }
        
        LMSButton(
            "Full Width Loading",
            variant: .primary,
            isFullWidth: true,
            isLoading: .constant(true)
        ) {
            print("Loading tapped")
        }
    }
    .padding()
}

#Preview("Dark Mode") {
    VStack(spacing: 16) {
        LMSButton("Primary", variant: .primary) {
            print("Primary tapped")
        }
        
        LMSButton("Secondary", variant: .secondary) {
            print("Secondary tapped")
        }
        
        LMSButton("Ghost", variant: .ghost) {
            print("Ghost tapped")
        }
    }
    .padding()
    .background(Color(.systemBackground))
    .preferredColorScheme(.dark)
}
