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
    case sendEmailList
    case emailRecipients
    case logout
}

// MARK: - MenuView

struct MenuView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager
    let onAction: (MenuAction) -> Void

    @State private var menuVisible = false

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
            .opacity(menuVisible ? 1 : 0)
            .offset(y: menuVisible ? 0 : -8)
            .animation(.easeOut(duration: 0.3), value: menuVisible)

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

                    LMSButton(localizationManager.localize("menu.sendEmailList"), icon: "envelope.fill", variant: .ghost, isFullWidth: true, contentAlignment: .leading) {
                        onAction(.sendEmailList)
                    }

                    LMSButton(localizationManager.localize("menu.emailRecipients"), icon: "person.2.fill", variant: .ghost, isFullWidth: true, contentAlignment: .leading) {
                        onAction(.emailRecipients)
                    }
                }

                Section {
                    LMSButton(localizationManager.localize("menu.logout"), icon: "arrow.right.square", variant: .destructive, isFullWidth: true, contentAlignment: .leading) {
                        onAction(.logout)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .opacity(menuVisible ? 1 : 0)
            .animation(.easeOut(duration: 0.35).delay(0.08), value: menuVisible)
        }
        .background(Color(.systemBackground))
        .task {
            withAnimation(.easeOut(duration: 0.3)) { menuVisible = true }
        }
    }
}

#Preview {
    MenuView(onAction: { _ in })
        .environmentObject(LocalizationManager.shared)
}
