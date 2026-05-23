//
//  ForgotPasswordView.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 21/1/26.
//

import SwiftUI

// MARK: - Forgot Password Placeholder

struct ForgotPasswordView: View {
    @EnvironmentObject private var localizationManager: LocalizationManager

    @State private var contentVisible = false
    @State private var floatOffset: CGFloat = -6

    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "lock.rotation")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
                .padding(.bottom, 16)
                .offset(y: floatOffset)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                        floatOffset = 6
                    }
                }
            LMSLabel(localizationManager.localize("forgotPassword.title"), style: .title, alignment: .center)
                .padding(.bottom, 8)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 16)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: contentVisible)
            LMSLabel(localizationManager.localize("forgotPassword.message"), style: .body, color: .secondary, alignment: .center)
                .opacity(contentVisible ? 1 : 0)
                .offset(y: contentVisible ? 0 : 16)
                .animation(.easeOut(duration: 0.4).delay(0.18), value: contentVisible)
            Spacer()
        }
        .padding()
        .navigationTitle(localizationManager.localize("forgotPassword.title"))
        .task {
            withAnimation(.easeOut(duration: 0.4)) { contentVisible = true }
        }
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(LocalizationManager.shared)
}
