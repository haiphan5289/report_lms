//
//  ProfileView.swift
//  report_lms
//

import SwiftUI
import UIKit

// MARK: - ProfileView

struct ProfileView: View {

    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject private var localizationManager: LocalizationManager
    @FocusState private var isNameFieldFocused: Bool
    @State private var contentVisible = false
    @State private var didCopyJoinCode = false

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                displayNameSection
                companyCodeSection
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

    // MARK: - Company Code Section

    private var companyCodeSection: some View {
        LMSSectionContainer(title: localizationManager.localize("profile.section.companyCode")) {
            VStack(alignment: .leading, spacing: 8) {
                LMSLabel(
                    localizationManager.localize("profile.companyCode.hint"),
                    style: .caption,
                    color: .secondary
                )

                if let joinCode = viewModel.companyJoinCode {
                    HStack(spacing: 12) {
                        LMSInfoRow(
                            label: localizationManager.localize("profile.section.companyCode"),
                            value: joinCode,
                            valueStyle: .headline,
                            backgroundColor: LMSColor.primaryLight
                        )
                        .frame(maxWidth: .infinity)

                        LMSButton(
                            localizationManager.localize(
                                didCopyJoinCode ? "profile.companyCode.copied" : "profile.companyCode.copy"
                            ),
                            icon: didCopyJoinCode ? "checkmark" : "doc.on.doc",
                            variant: .iconOnly
                        ) {
                            copyJoinCode(joinCode)
                        }
                    }
                } else if viewModel.isLoadingCompanyJoinCode {
                    LMSLabel(localizationManager.localize("common.loading"), style: .caption, color: .secondary)
                }
            }
        }
    }

    private func copyJoinCode(_ code: String) {
        UIPasteboard.general.string = code
        withAnimation(.easeOut(duration: 0.2)) { didCopyJoinCode = true }
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeOut(duration: 0.2)) { didCopyJoinCode = false }
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
