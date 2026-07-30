//
//  LoginView.swift
//  report_lms
//
//  Created by AI on January 20, 2026.
//

import SwiftUI
import LocalAuthentication

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
    @EnvironmentObject private var localizationManager: LocalizationManager

    // Animation
    @State private var titleVisible = false
    @State private var formVisible = false
    @State private var shakeOffset: CGFloat = 0
    @GestureState private var biometricPressed = false

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
                .opacity(titleVisible ? 1 : 0)
                .offset(y: titleVisible ? 0 : -16)
                .animation(.easeOut(duration: 0.45), value: titleVisible)
            formSection
                .opacity(formVisible ? 1 : 0)
                .offset(y: formVisible ? 0 : 20)
                .offset(x: shakeOffset)
                .animation(.easeOut(duration: 0.4), value: formVisible)
            actionSection
                .opacity(formVisible ? 1 : 0)
                .offset(y: formVisible ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.08), value: formVisible)

            Spacer()
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .task {
            withAnimation(.easeOut(duration: 0.45)) { titleVisible = true }
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeOut(duration: 0.4)) { formVisible = true }
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            guard newValue != nil else { return }
            withAnimation(.easeInOut(duration: 0.06).repeatCount(4, autoreverses: true)) {
                shakeOffset = 8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation { shakeOffset = 0 }
            }
        }
    }

    private var titleSection: some View {
        VStack(spacing: Layout.formSpacing) {
            LMSLabel("IPSLMS", style: .largeTitle, alignment: .center)
            LMSLabel(
                localizationManager.localize("login.subtitle"),
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
            localizationManager.localize("login.email"),
            text: $viewModel.username,
            icon: "envelope",
            keyboardType: .emailAddress
        )
    }

    private var passwordTextField: some View {
        LMSTextField(
            localizationManager.localize("login.password"),
            text: $viewModel.password,
            icon: "lock",
            isSecure: true
        )
    }

    private var forgotPasswordLink: some View {
        HStack {
            Spacer()
            NavigationLink(destination: ForgotPasswordView(viewModel: Container.shared.resolve(ForgotPasswordViewModel.self)!)) {
                Text(localizationManager.localize("login.forgotPassword"))
                    .font(.footnote)
                    .foregroundColor(.accentColor)
                    .padding(.vertical, Layout.forgotPasswordVerticalPadding)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    private var signUpLink: some View {
        HStack {
            Text("Chưa có tài khoản?")
                .font(.footnote)
                .foregroundColor(.secondary)
            NavigationLink(destination: SignUpView(viewModel: Container.shared.resolve(SignUpViewModel.self)!)) {
                Text("Đăng ký")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, Layout.forgotPasswordVerticalPadding)
    }

    private var actionSection: some View {
        VStack(spacing: Layout.errorSpacing) {
            if let error = viewModel.errorMessage {
                errorView(message: error)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            loginButton
            biometricButton
            signUpLink
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.errorMessage == nil)
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
            viewModel.isLoginLoading
                ? localizationManager.localize("login.button.loading")
                : localizationManager.localize("login.button"),
            variant: .primary,
            isFullWidth: true,
            isLoading: .constant(viewModel.isLoginLoading),
            isDisabled: isLoginButtonDisabled
        ) {
            Task { await viewModel.login() }
        }
    }

    private var biometricButton: some View {
        Group {
            if viewModel.isBiometricAvailable {
                VStack(spacing: 8) {
                    Text(localizationManager.localize("common.or"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        Task { await viewModel.biometricLogin() }
                    }) {
                        ZStack {
                            Circle()
                                .fill(LMSColor.primaryLight)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle()
                                        .stroke(LMSColor.primaryBorder, lineWidth: 2)
                                )

                            if viewModel.isBiometricLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            } else {
                                Image(systemName: biometricIconName)
                                    .font(.system(size: 32))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .disabled(viewModel.isBiometricLoading)
                    .opacity(viewModel.isBiometricLoading ? 0.6 : 1.0)
                    .scaleEffect(biometricPressed ? 0.93 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: biometricPressed)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .updating($biometricPressed) { _, state, _ in state = true }
                    )
                    
                    Text(biometricButtonTitle)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var biometricButtonTitle: String {
        switch viewModel.biometricType {
        case .faceID:
            return localizationManager.localize("login.biometric.faceID")
        case .touchID:
            return localizationManager.localize("login.biometric.touchID")
        default:
            return localizationManager.localize("login.biometric.generic")
        }
    }

    private var biometricIconName: String {
        switch viewModel.biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "person.fill"
        }
    }

    private var isLoginButtonDisabled: Bool {
        viewModel.isLoginLoading || viewModel.username.isEmpty || viewModel.password.isEmpty
    }
}

// MARK: - Preview

#Preview {
    let service = AuthService()
    let repository = AuthRepository(service: service)
    let useCase = LoginUseCase(repository: repository)
    let companyRepository = CompanyRepository(service: CompanyService())
    let fetchUserProfileUseCase = FetchUserProfileUseCase(repository: companyRepository)
    let userManager = Container.shared.resolve(UserManager.self)!
    let storageService = Container.shared.resolve(InspectionStorageServiceType.self)!
    let viewModel = LoginViewModel(
        loginUseCase: useCase,
        fetchUserProfileUseCase: fetchUserProfileUseCase,
        storageService: storageService,
        userManager: userManager
    )
    // Simulate biometric availability for preview
    viewModel.isBiometricAvailable = true
    viewModel.biometricType = .faceID
    
    return NavigationStack {
        LoginView(viewModel: viewModel)
            .environmentObject(LocalizationManager.shared)
    }
}
