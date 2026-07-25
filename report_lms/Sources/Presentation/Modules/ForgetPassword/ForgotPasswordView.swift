//
//  ForgotPasswordView.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 21/1/26.
//

import SwiftUI

struct ForgotPasswordView: View {
    private enum Layout {
        static let horizontalPadding: CGFloat = 24
        static let mainSpacing: CGFloat = 20
        static let formSpacing: CGFloat = 12
    }

    @EnvironmentObject private var localizationManager: LocalizationManager
    @StateObject private var viewModel: ForgotPasswordViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var contentVisible = false
    @State private var floatOffset: CGFloat = -6

    init(viewModel: ForgotPasswordViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: Layout.mainSpacing) {
            Spacer()

            iconView

            LMSLabel(localizationManager.localize("forgotPassword.title"), style: .title, alignment: .center)
            LMSLabel(localizationManager.localize("forgotPassword.message"), style: .body, color: .secondary, alignment: .center)

            if viewModel.isSuccess {
                successView
            } else {
                formView
            }

            Spacer()
        }
        .opacity(contentVisible ? 1 : 0)
        .offset(y: contentVisible ? 0 : 16)
        .animation(.easeOut(duration: 0.4).delay(0.1), value: contentVisible)
        .padding(.horizontal, Layout.horizontalPadding)
        .navigationTitle(localizationManager.localize("forgotPassword.title"))
        .task {
            withAnimation(.easeOut(duration: 0.4)) { contentVisible = true }
        }
    }

    private var iconView: some View {
        Image(systemName: viewModel.isSuccess ? "checkmark.circle.fill" : "lock.rotation")
            .resizable()
            .scaledToFit()
            .frame(width: 80, height: 80)
            .foregroundColor(viewModel.isSuccess ? LMSColor.success : .accentColor)
            .padding(.bottom, 8)
            .offset(y: viewModel.isSuccess ? 0 : floatOffset)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isSuccess)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    floatOffset = 6
                }
            }
    }

    private var formView: some View {
        VStack(spacing: Layout.formSpacing) {
            LMSTextField(
                localizationManager.localize("forgotPassword.emailPlaceholder"),
                text: $viewModel.email,
                icon: "envelope",
                validationState: viewModel.errorMessage == nil ? .normal : .error,
                helperText: viewModel.errorMessage,
                keyboardType: .emailAddress,
                autocapitalization: .never,
                onCommit: { Task { await viewModel.sendResetLink() } }
            )

            LMSButton(
                viewModel.isLoading
                    ? localizationManager.localize("forgotPassword.button.loading")
                    : localizationManager.localize("forgotPassword.button"),
                variant: .primary,
                isFullWidth: true,
                isLoading: .constant(viewModel.isLoading),
                isDisabled: viewModel.isLoading || viewModel.email.isEmpty
            ) {
                Task { await viewModel.sendResetLink() }
            }
        }
        .padding(.top, 8)
    }

    private var successView: some View {
        VStack(spacing: Layout.formSpacing) {
            LMSLabel(
                localizationManager.localize("forgotPassword.success"),
                style: .body,
                color: .secondary,
                alignment: .center
            )

            LMSButton(
                localizationManager.localize("forgotPassword.backToLogin"),
                variant: .secondary,
                isFullWidth: true
            ) {
                dismiss()
            }
        }
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

// MARK: - Preview

#Preview {
    let service = AuthService()
    let repository = AuthRepository(service: service)
    let useCase = ForgotPasswordUseCase(repository: repository)
    let viewModel = ForgotPasswordViewModel(forgotPasswordUseCase: useCase)

    return NavigationStack {
        ForgotPasswordView(viewModel: viewModel)
            .environmentObject(LocalizationManager.shared)
    }
}
