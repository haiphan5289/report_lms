//
//  MenuView.swift
//  report_lms
//
//  Created by AI on February 6, 2026.
//

import SwiftUI

// MARK: - MenuAction

enum MenuAction {
    case profile
    case settings
    case orders
    case logout
}

// MARK: - MenuView

struct MenuView: View {
    let onAction: (MenuAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                LMSLabel("Menu", style: .title2)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // Menu items
            List {
                Section {
                    LMSButton("Profile", icon: "person.circle", variant: .ghost, isFullWidth: true, contentAlignment: .leading) {
                        onAction(.profile)
                    }

                    LMSButton("Settings", icon: "gear", variant: .ghost, isFullWidth: true, contentAlignment: .leading) {
                        onAction(.settings)
                    }

                    LMSButton("Orders", icon: "cart", variant: .ghost, isFullWidth: true, contentAlignment: .leading) {
                        onAction(.orders)
                    }
                }

                Section {
                    LMSButton("Logout", icon: "arrow.right.square", variant: .destructive, isFullWidth: true, contentAlignment: .leading) {
                        onAction(.logout)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    MenuView(onAction: { _ in })
}
