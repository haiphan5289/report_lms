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
                    Button(action: {
                        // Profile action - could navigate to profile screen
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "person.circle")
                                .foregroundColor(.blue)
                            LMSLabel("Profile", style: .body, color: .primary)
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        // Settings action - could navigate to settings screen
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.gray)
                            LMSLabel("Settings", style: .body, color: .primary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    Button(action: {
                        onLogout()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .foregroundColor(.red)
                            LMSLabel("Logout", style: .body, color: .error)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Menu")
            .navigationBarItems(trailing: LMSButton("Done", variant: .ghost, size: .small, action: {
                dismiss()
            }))
        }
    }
}

#Preview {
    MenuView(onLogout: {})
}