//
//  JoinCompanyView.swift
//  report_lms
//

import SwiftUI

struct JoinCompanyView: View {
    private enum Layout {
        static let horizontalPadding: CGFloat = 24
        static let mainSpacing: CGFloat = 20
        static let formSpacing: CGFloat = 12
    }

    @StateObject private var viewModel: JoinCompanyViewModel

    @State private var contentVisible = false
    @State private var errorShakeOffset: CGFloat = 0
    @GestureState private var ctaPressed = false

    init(viewModel: JoinCompanyViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Layout.formSpacing) {
                LMSTextField("Mã công ty (do quản trị viên cung cấp)", text: $viewModel.joinCode, icon: "number")
                    .textInputAutocapitalization(.characters)
                    .staggeredEntrance(visible: contentVisible, index: 0)
                LMSTextField("Họ tên của bạn", text: $viewModel.displayName, icon: "person")
                    .staggeredEntrance(visible: contentVisible, index: 1)
                LMSTextField("Email", text: $viewModel.email, icon: "envelope", keyboardType: .emailAddress)
                    .staggeredEntrance(visible: contentVisible, index: 2)
                LMSTextField("Mật khẩu", text: $viewModel.password, icon: "lock", isSecure: true)
                    .staggeredEntrance(visible: contentVisible, index: 3)

                if let error = viewModel.errorMessage {
                    LMSLabel(error, style: .footnote, color: .error, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .offset(x: errorShakeOffset)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, 32)
        }
        .safeAreaInset(edge: .bottom) {
            ctaBar
        }
        .navigationTitle("Tham gia công ty")
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

    private var ctaBar: some View {
        VStack(spacing: 0) {
            Divider()
            LMSButton(
                viewModel.isLoading ? "Đang tham gia..." : "Tham gia công ty",
                variant: .primary,
                isFullWidth: true,
                isLoading: .constant(viewModel.isLoading),
                isDisabled: viewModel.isLoading || !viewModel.isFormValid
            ) {
                Task { await viewModel.joinCompany() }
            }
            .scaleEffect(ctaPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: ctaPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($ctaPressed) { _, state, _ in state = true }
            )
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
    }

}

#Preview {
    let authService = AuthService()
    let authRepository = AuthRepository(service: authService)
    let companyService = CompanyService()
    let companyRepository = CompanyRepository(service: companyService)
    let viewModel = JoinCompanyViewModel(
        signUpUseCase: SignUpUseCase(repository: authRepository),
        joinCompanyUseCase: JoinCompanyUseCase(repository: companyRepository),
        rollbackSignUpUseCase: RollbackSignUpUseCase(repository: authRepository),
        storageService: Container.shared.resolve(InspectionStorageServiceType.self)!,
        userManager: Container.shared.resolve(UserManager.self)!
    )
    return NavigationStack {
        JoinCompanyView(viewModel: viewModel)
    }
}
