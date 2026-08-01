//
//  SignUpView.swift
//  report_lms
//

import SwiftUI

struct SignUpView: View {
    private enum Layout {
        static let horizontalPadding: CGFloat = 24
        static let verticalPadding: CGFloat = 32
        static let sectionSpacing: CGFloat = 28
        static let heroSpacing: CGFloat = 8
        static let formSpacing: CGFloat = 12
        static let cardPadding: CGFloat = 16
        static let cardCornerRadius: CGFloat = 12
    }

    @StateObject private var viewModel: SignUpViewModel

    @State private var titleVisible = false
    @State private var contentVisible = false
    @State private var errorShakeOffset: CGFloat = 0
    @GestureState private var ctaPressed = false

    init(viewModel: SignUpViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Layout.sectionSpacing) {
                titleSection
                    .opacity(titleVisible ? 1 : 0)
                    .offset(y: titleVisible ? 0 : -12)
                    .animation(.easeOut(duration: 0.4), value: titleVisible)

                formContent
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
        }
        .safeAreaInset(edge: .bottom) {
            ctaBar
        }
        .navigationTitle("Đăng ký")
        .task {
            withAnimation(.easeOut(duration: 0.4)) {
                titleVisible = true
            }
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeOut(duration: 0.35)) {
                contentVisible = true
            }
        }
        .onChange(of: viewModel.errorMessage) { _, newValue in
            guard newValue != nil else { return }
            $errorShakeOffset.triggerShake()
        }
    }

    private var titleSection: some View {
        VStack(spacing: Layout.heroSpacing) {
            ZStack {
                Circle()
                    .fill(LMSColor.primaryLight)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle().stroke(LMSColor.primaryBorder, lineWidth: 2)
                    )
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(LMSColor.primary)
            }
            LMSLabel("Tạo tài khoản", style: .title2, alignment: .center)
            LMSLabel(
                "Điền thông tin để bắt đầu sử dụng IPSLMS",
                style: .caption,
                color: .secondary,
                alignment: .center
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var formContent: some View {
        VStack(spacing: Layout.formSpacing) {
            LMSSectionContainer(cornerRadius: Layout.cardCornerRadius, padding: Layout.cardPadding) {
                LMSTextField("Họ tên của bạn", text: $viewModel.displayName, icon: "person")
                    .staggeredEntrance(visible: contentVisible, index: 0)
                LMSTextField("Email", text: $viewModel.email, icon: "envelope", keyboardType: .emailAddress)
                    .staggeredEntrance(visible: contentVisible, index: 1)
                LMSTextField("Mật khẩu", text: $viewModel.password, icon: "lock", isSecure: true)
                    .staggeredEntrance(visible: contentVisible, index: 2)
            }
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cardCornerRadius)
                    .stroke(LMSColor.Border.subtle, lineWidth: 1)
            )
            .shadow(color: LMSColor.Shadow.subtle, radius: 6, x: 0, y: 3)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 16)
            .animation(.easeOut(duration: 0.35), value: contentVisible)

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
                .padding(.vertical, Layout.formSpacing)
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
    let viewModel = SignUpViewModel(
        signUpUseCase: SignUpUseCase(repository: authRepository),
        updateDisplayNameUseCase: UpdateDisplayNameUseCase(repository: authRepository),
        storageService: Container.shared.resolve(InspectionStorageServiceType.self)!,
        userManager: Container.shared.resolve(UserManager.self)!
    )
    return NavigationStack {
        SignUpView(viewModel: viewModel)
    }
}
