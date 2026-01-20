//
//  LoginView.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel: LoginViewModel
    
    init(viewModel: LoginViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 32)

            VStack(spacing: 12) {
                LMSLabel("IPSLMS", style: .largeTitle, alignment: .center)
                LMSLabel("Đăng nhập bằng email", style: .caption, color: .secondary, alignment: .center)

                LMSTextField(
                    "Email",
                    text: $viewModel.username,
                    icon: "envelope",
                    keyboardType: .emailAddress
                )

                LMSTextField(
                    "Mật khẩu",
                    text: $viewModel.password,
                    icon: "lock",
                    isSecure: true
                )
            }

            VStack(spacing: 4) {
                if let error = viewModel.errorMessage {
                    HStack(alignment: .center, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        LMSLabel(error, style: .footnote, color: .error, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 0)
                }

                LMSButton(
                    viewModel.isLoading ? "Đang đăng nhập..." : "Đăng nhập",
                    variant: .primary,
                    isFullWidth: true,
                    isLoading: .constant(viewModel.isLoading),
                    isDisabled: viewModel.isLoading || viewModel.username.isEmpty || viewModel.password.isEmpty
                ) {
                    Task { await viewModel.login() }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
    }
}

// MARK: - Preview

#Preview {
    let service = AuthService()
    let repository = AuthRepository(service: service)
    let useCase = LoginUseCase(repository: repository)
    let viewModel = LoginViewModel(loginUseCase: useCase)
    LoginView(viewModel: viewModel)
}
