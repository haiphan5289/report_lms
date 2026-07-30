//
//  ProfileView.swift
//  report_lms
//

import SwiftUI

// MARK: - ProfileView

struct ProfileView: View {

    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject private var localizationManager: LocalizationManager
    @FocusState private var isNameFieldFocused: Bool
    @State private var contentVisible = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                displayNameSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .background(LMSColor.backgroundGrouped)
        .navigationTitle(localizationManager.localize("profile.title"))
        .navigationBarTitleDisplayMode(.large)
        .opacity(contentVisible ? 1 : 0)
        .offset(y: contentVisible ? 0 : 16)
        .animation(.easeOut(duration: 0.4), value: contentVisible)
        .task {
            viewModel.loadCurrentDisplayName()
            withAnimation(.easeOut(duration: 0.4)) { contentVisible = true }
        }
        .overlay {
            if viewModel.showSaveSuccess {
                SuccessConfirmationView(
                    title: localizationManager.localize("profile.success.title"),
                    message: localizationManager.localize("profile.success.message"),
                    confirmTitle: localizationManager.localize("common.ok")
                ) {
                    viewModel.showSaveSuccess = false
                }
            }
        }
    }

    // MARK: - Display Name Section

    private var displayNameSection: some View {
        LMSSectionContainer(title: localizationManager.localize("profile.section.displayName")) {
            VStack(alignment: .leading, spacing: 8) {
                LMSLabel(
                    localizationManager.localize("profile.displayName.hint"),
                    style: .caption,
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

                LMSButton(
                    localizationManager.localize("common.save"),
                    variant: .primary,
                    size: .medium,
                    isFullWidth: true,
                    isLoading: $viewModel.isSaving,
                    isDisabled: viewModel.isSaving
                ) {
                    isNameFieldFocused = false
                    Task { await viewModel.save() }
                }
                .padding(.top, 4)
            }
        }
    }

}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(LocalizationManager.shared)
    }
}
