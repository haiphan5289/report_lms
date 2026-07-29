//
//  DisplayNameRequiredSheet.swift
//  report_lms
//

import SwiftUI

/// Hard-blocking sheet shown when a user tries to generate a PDF report without having
/// set a display name yet. No dismiss/cancel — saving a valid name is the only way out.
struct DisplayNameRequiredSheet: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject private var localizationManager: LocalizationManager
    @FocusState private var isNameFieldFocused: Bool
    let onSaved: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                LMSLabel(
                    localizationManager.localize("profile.gate.message"),
                    style: .body,
                    color: .secondary
                )

                TextField(
                    localizationManager.localize("profile.displayName.placeholder"),
                    text: $viewModel.displayName
                )
                .focused($isNameFieldFocused)
                .padding(12)
                .background(LMSColor.backgroundSecondary)
                .cornerRadius(8)
                .font(.system(size: 15))
                .onChange(of: viewModel.displayName) { _, newValue in
                    if newValue.count > ProfileViewModel.displayNameMaxLength {
                        viewModel.displayName = String(newValue.prefix(ProfileViewModel.displayNameMaxLength))
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    LMSLabel(errorMessage, style: .caption, color: .error)
                }

                Spacer()

                LMSButton(
                    localizationManager.localize("profile.gate.saveAndContinue"),
                    variant: .primary,
                    size: .large,
                    isFullWidth: true,
                    isLoading: $viewModel.isSaving,
                    isDisabled: viewModel.isSaving
                ) {
                    isNameFieldFocused = false
                    Task {
                        await viewModel.save()
                        if viewModel.errorMessage == nil {
                            onSaved()
                        }
                    }
                }
            }
            .padding(20)
            .navigationTitle(localizationManager.localize("profile.gate.title"))
            .navigationBarTitleDisplayMode(.inline)
            .task {
                isNameFieldFocused = true
            }
        }
        .interactiveDismissDisabled(true)
    }
}

// MARK: - Preview

#Preview {
    DisplayNameRequiredSheet(onSaved: {})
        .environmentObject(LocalizationManager.shared)
}
