//
//  SettingsView.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 13/4/26.
//

import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {

    @EnvironmentObject private var localizationManager: LocalizationManager

    // MARK: - Body

    var body: some View {
        List {
            languageSection
        }
        .navigationTitle(localizationManager.localize("settings.title"))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Language Section

    private var languageSection: some View {
        Section(header: Text(localizationManager.localize("settings.section.language"))) {
            languageRow
        }
    }

    private var languageRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .foregroundColor(.accentColor)
                .frame(width: 24)

            Text(localizationManager.localize("settings.language.label"))
                .foregroundColor(.primary)

            Spacer()

            Text(localizationManager.currentLanguage == .vietnamese
                 ? localizationManager.localize("settings.language.vietnamese")
                 : localizationManager.localize("settings.language.english"))
                .foregroundColor(.secondary)
                .font(.subheadline)

            Toggle(
                "",
                isOn: Binding(
                    get: { localizationManager.currentLanguage == .english },
                    set: { isEnglish in
                        localizationManager.setLanguage(isEnglish ? .english : .vietnamese)
                    }
                )
            )
            .labelsHidden()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(LocalizationManager.shared)
    }
}
