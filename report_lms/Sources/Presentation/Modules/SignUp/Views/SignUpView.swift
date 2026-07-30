//
//  SignUpView.swift
//  report_lms
//

import SwiftUI

struct SignUpView: View {
    private enum Layout {
        static let horizontalPadding: CGFloat = 24
        static let formSpacing: CGFloat = 12
    }

    @StateObject private var viewModel: SignUpViewModel

    @State private var contentVisible = false
    @State private var errorShakeOffset: CGFloat = 0
    @GestureState private var ctaPressed = false

    init(viewModel: SignUpViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            formContent
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.vertical, 32)
        }
        .safeAreaInset(edge: .bottom) {
            ctaBar
        }
        .navigationTitle("Đăng ký")
        .task {
            withAnimation(.easeOut(duration: 0.35)) {
                contentVisible = true
            }
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            guard newValue != nil else { return }
            $errorShakeOffset.triggerShake()
        }
    }

    private var formContent: some View {
        VStack(spacing: Layout.formSpacing) {
            LMSTextField("Họ tên của bạn", text: $viewModel.displayName, icon: "person")
                .staggeredEntrance(visible: contentVisible, index: 0)
            LMSTextField("Email", text: $viewModel.email, icon: "envelope", keyboardType: .emailAddress)
                .staggeredEntrance(visible: contentVisible, index: 1)
            LMSTextField("Mật khẩu", text: $viewModel.password, icon: "lock", isSecure: true)
                .staggeredEntrance(visible: contentVisible, index: 2)

            if let error = viewModel.errorMessage {
                LMSLabel(error, style: .footnote, color: .error, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .offset(x: errorShakeOffset)
                    .transition(.opacity)
            }
        }
    }

    private var ctaBar: some View {
        VStack(spacing: 0) {
            Divider()
            ctaButton
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
    }

    private var ctaButton: some View {
        LMSButton(
            viewModel.isLoading ? "Đang đăng ký..." : "Đăng ký",
            variant: .primary,
            isFullWidth: true,
            isLoading: .constant(viewModel.isLoading),
            isDisabled: viewModel.isLoading || !viewModel.isFormValid
        ) {
            Task { await viewModel.signUp() }
        }
        .scaleEffect(ctaPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: ctaPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($ctaPressed) { _, state, _ in state = true }
        )
    }
}

#Preview {
    let authRepository = AuthRepository(service: AuthService())
    let companyRepository = CompanyRepository(service: CompanyService())
    let viewModel = SignUpViewModel(
        signUpUseCase: SignUpUseCase(repository: authRepository),
        updateDisplayNameUseCase: UpdateDisplayNameUseCase(repository: authRepository),
        createCompanyUseCase: CreateCompanyUseCase(repository: companyRepository),
        rollbackSignUpUseCase: RollbackSignUpUseCase(repository: authRepository),
        storageService: Container.shared.resolve(InspectionStorageServiceType.self)!,
        userManager: Container.shared.resolve(UserManager.self)!
    )
    return NavigationStack {
        SignUpView(viewModel: viewModel)
    }
}
