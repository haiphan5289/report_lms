//
//  CreateCompanyView.swift
//  report_lms
//

import SwiftUI

struct CreateCompanyView: View {
    private enum Layout {
        static let horizontalPadding: CGFloat = 24
        static let mainSpacing: CGFloat = 20
        static let formSpacing: CGFloat = 12
    }

    @StateObject private var viewModel: CreateCompanyViewModel

    @State private var contentVisible = false
    @State private var checkmarkPop = false
    @State private var errorShakeOffset: CGFloat = 0
    @GestureState private var ctaPressed = false

    init(viewModel: CreateCompanyViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Layout.mainSpacing) {
                if viewModel.isSuccess {
                    successContent
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    formContent
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: viewModel.isSuccess)
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, 32)
        }
        .safeAreaInset(edge: .bottom) {
            ctaBar
        }
        .navigationTitle("Tạo công ty mới")
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
            LMSTextField("Tên công ty", text: $viewModel.companyName, icon: "building.2")
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
    }

    private var successContent: some View {
        VStack(spacing: Layout.formSpacing) {
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(LMSColor.success)
                .scaleEffect(checkmarkPop ? 1 : 0.4)
                .opacity(checkmarkPop ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.5), value: checkmarkPop)
                .onAppear { checkmarkPop = true }

            LMSLabel("Tạo công ty thành công!", style: .title, alignment: .center)
            LMSLabel(
                "Chia sẻ mã dưới đây cho các thanh tra viên để họ tham gia công ty của bạn:",
                style: .body,
                color: .secondary,
                alignment: .center
            )

            Text(viewModel.createdJoinCode ?? "")
                .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(LMSColor.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
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
        Group {
            if viewModel.isSuccess {
                LMSButton("Bắt đầu", variant: .primary, isFullWidth: true) {
                    viewModel.finishOnboarding()
                }
            } else {
                LMSButton(
                    viewModel.isLoading ? "Đang tạo..." : "Tạo công ty",
                    variant: .primary,
                    isFullWidth: true,
                    isLoading: .constant(viewModel.isLoading),
                    isDisabled: viewModel.isLoading || !viewModel.isFormValid
                ) {
                    Task { await viewModel.createCompany() }
                }
            }
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
    let authService = AuthService()
    let authRepository = AuthRepository(service: authService)
    let companyService = CompanyService()
    let companyRepository = CompanyRepository(service: companyService)
    let viewModel = CreateCompanyViewModel(
        signUpUseCase: SignUpUseCase(repository: authRepository),
        createCompanyUseCase: CreateCompanyUseCase(repository: companyRepository),
        rollbackSignUpUseCase: RollbackSignUpUseCase(repository: authRepository),
        storageService: Container.shared.resolve(InspectionStorageServiceType.self)!,
        userManager: Container.shared.resolve(UserManager.self)!
    )
    return NavigationStack {
        CreateCompanyView(viewModel: viewModel)
    }
}
