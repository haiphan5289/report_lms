//
//  LoginView.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//

import SwiftUI

struct LoginView: View {
    // MARK: - Constants
    private enum Layout {
        static let topSpacing: CGFloat = 32
        static let mainSpacing: CGFloat = 28
        static let formSpacing: CGFloat = 12
        static let errorSpacing: CGFloat = 4
        static let errorIconSpacing: CGFloat = 6
        static let horizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 32
        static let forgotPasswordVerticalPadding: CGFloat = 4
    }
    
    // MARK: - Properties
    @StateObject private var viewModel: LoginViewModel
    
    // MARK: - Initialization
    init(viewModel: LoginViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            contentView
        }
    }
    
    private var contentView: some View {
        VStack(spacing: Layout.mainSpacing) {
            Spacer().frame(height: Layout.topSpacing)
            
            titleSection
            formSection
            actionSection
            
            Spacer()
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
    }
    
    private var titleSection: some View {
        VStack(spacing: Layout.formSpacing) {
            LMSLabel("IPSLMS", style: .largeTitle, alignment: .center)
            LMSLabel(
                "Đăng nhập bằng email",
                style: .caption,
                color: .secondary,
                alignment: .center
            )
        }
    }
    
    private var formSection: some View {
        VStack(spacing: Layout.formSpacing) {
            emailTextField
            passwordTextField
            forgotPasswordLink
        }
    }
    
    private var emailTextField: some View {
        LMSTextField(
            "Email",
            text: $viewModel.username,
            icon: "envelope",
            keyboardType: .emailAddress
        )
    }
    
    private var passwordTextField: some View {
        LMSTextField(
            "Mật khẩu",
            text: $viewModel.password,
            icon: "lock",
            isSecure: true
        )
    }
    
    private var forgotPasswordLink: some View {
        HStack {
            Spacer()
            NavigationLink(destination: ForgotPasswordView()) {
                Text("Quên mật khẩu?")
                    .font(.footnote)
                    .foregroundColor(.accentColor)
                    .padding(.vertical, Layout.forgotPasswordVerticalPadding)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var actionSection: some View {
        VStack(spacing: Layout.errorSpacing) {
            if let error = viewModel.errorMessage {
                errorView(message: error)
            }
            
            loginButton
        }
    }
    
    private func errorView(message: String) -> some View {
        HStack(alignment: .center, spacing: Layout.errorIconSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.caption)
            LMSLabel(
                message,
                style: .footnote,
                color: .error,
                alignment: .leading
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 0)
    }
    
    private var loginButton: some View {
        LMSButton(
            viewModel.isLoading ? "Đang đăng nhập..." : "Đăng nhập",
            variant: .primary,
            isFullWidth: true,
            isLoading: .constant(viewModel.isLoading),
            isDisabled: isLoginButtonDisabled
        ) {
            Task { await viewModel.login() }
        }
    }
    
    private var isLoginButtonDisabled: Bool {
        viewModel.isLoading || viewModel.username.isEmpty || viewModel.password.isEmpty
    }
}

// MARK: - Preview

#Preview {
    let service = AuthService()
    let repository = AuthRepository(service: service)
    let useCase = LoginUseCase(repository: repository)
    let userManager = Container.shared.resolve(UserManager.self)!
    let viewModel = LoginViewModel(loginUseCase: useCase, userManager: userManager)
    NavigationStack {
        LoginView(viewModel: viewModel)
    }
}
