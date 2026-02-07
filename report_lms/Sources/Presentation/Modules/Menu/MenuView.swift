//
//  MenuView.swift
//  report_lms
//
//  Created by AI on February 6, 2026.
//

import SwiftUI

/// Menu view shown when user taps the menu button in the header
struct MenuView: View {
    let onLogout: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section {
                    LMSButton("Profile", icon: "person.circle", variant: .ghost, isFullWidth: true, contentAlignment: .leading) {
                        // Profile action - could navigate to profile screen
                        dismiss()
                    }

                    LMSButton("Settings", icon: "gear", variant: .ghost, isFullWidth: true, contentAlignment: .leading) {
                        // Settings action - could navigate to settings screen
                        dismiss()
                    }
                }

                Section {
                    LMSButton("Logout", icon: "arrow.right.square", variant: .destructive, isFullWidth: true, contentAlignment: .leading) {
                        onLogout()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Menu")
            .shadow(color: LMSColor.Shadow.subtle, radius: 2, y: 1)
        }
    }
}

#Preview {
    MenuView(onLogout: {})
}
