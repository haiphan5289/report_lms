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
    @EnvironmentObject private var localizationManager: LocalizationManager
    let onAction: (MenuAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                LMSLabel(localizationManager.localize("menu.title"), style: .title2)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // Menu items
            List {
                Section {
                    LMSButton(localizationManager.localize("menu.profile"), icon: "person.circle", variant: .ghost, isFullWidth: true, contentAlignment: .leading) {
                        onAction(.profile)
                    }

                    LMSButton(localizationManager.localize("menu.settings"), icon: "gear", variant: .ghost, isFullWidth: true, contentAlignment: .leading) {
                        onAction(.settings)
                    }

                    LMSButton(localizationManager.localize("menu.orders"), icon: "cart", variant: .ghost, isFullWidth: true, contentAlignment: .leading) {
                        onAction(.orders)
                    }
                }

                Section {
                    LMSButton(localizationManager.localize("menu.logout"), icon: "arrow.right.square", variant: .destructive, isFullWidth: true, contentAlignment: .leading) {
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
        .environmentObject(LocalizationManager.shared)
}
