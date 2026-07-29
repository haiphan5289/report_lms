//
//  SignUpChoiceView.swift
//  report_lms
//

import SwiftUI

struct SignUpChoiceView: View {
    private enum Layout {
        static let horizontalPadding: CGFloat = 24
        static let mainSpacing: CGFloat = 20
    }

    @State private var heroVisible = false
    @State private var choicesVisible = false

    var body: some View {
        VStack(spacing: Layout.mainSpacing) {
            Spacer()

            VStack(spacing: Layout.mainSpacing) {
                Image(systemName: "building.2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.accentColor)

                LMSLabel("Tạo tài khoản mới", style: .title, alignment: .center)
                LMSLabel(
                    "Bạn đại diện cho một công ty mới, hay đã có mã mời từ công ty của bạn?",
                    style: .body,
                    color: .secondary,
                    alignment: .center
                )
            }
            .opacity(heroVisible ? 1 : 0)
            .offset(y: heroVisible ? 0 : 16)

            VStack(spacing: 12) {
                NavigationLink(destination: CreateCompanyView(viewModel: Container.shared.resolve(CreateCompanyViewModel.self)!)) {
                    Text("Tạo công ty mới")
                }
                .buttonStyle(SignUpChoiceButtonStyle(variant: .primary))

                NavigationLink(destination: JoinCompanyView(viewModel: Container.shared.resolve(JoinCompanyViewModel.self)!)) {
                    Text("Tham gia công ty (có mã mời)")
                }
                .buttonStyle(SignUpChoiceButtonStyle(variant: .secondary))
            }
            .padding(.top, 8)
            .opacity(choicesVisible ? 1 : 0)
            .offset(y: choicesVisible ? 0 : 16)

            Spacer()
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .navigationTitle("Đăng ký")
        .task {
            withAnimation(.easeOut(duration: 0.4)) {
                heroVisible = true
            }
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeOut(duration: 0.4)) {
                choicesVisible = true
            }
        }
    }
}

private struct SignUpChoiceButtonStyle: ButtonStyle {
    enum Variant {
        case primary
        case secondary
    }

    private enum Metrics {
        static let verticalPadding: CGFloat = 14
        static let cornerRadius: CGFloat = 12
        static let borderWidth: CGFloat = 1.5
        static let pressedOpacity: CGFloat = 0.85
        static let pressedScale: CGFloat = 0.98
        static let pressAnimationDuration: Double = 0.15
    }

    let variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LMSButtonSize.medium.fontSize)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Metrics.verticalPadding)
            .foregroundColor(variant == .primary ? LMSColor.Button.primaryForeground : LMSColor.primary)
            .background(variant == .primary ? LMSColor.Button.primaryBackground : LMSColor.clear)
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cornerRadius)
                    .stroke(variant == .secondary ? LMSColor.primary : LMSColor.clear, lineWidth: Metrics.borderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: Metrics.cornerRadius))
            .opacity(configuration.isPressed ? Metrics.pressedOpacity : 1.0)
            .scaleEffect(configuration.isPressed ? Metrics.pressedScale : 1.0)
            .animation(.easeOut(duration: Metrics.pressAnimationDuration), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        SignUpChoiceView()
    }
}
