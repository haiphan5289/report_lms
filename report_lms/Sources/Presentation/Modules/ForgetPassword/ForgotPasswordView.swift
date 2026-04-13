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

    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "lock.rotation")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
                .padding(.bottom, 16)
            LMSLabel(localizationManager.localize("forgotPassword.title"), style: .title, alignment: .center)
                .padding(.bottom, 8)
            LMSLabel(localizationManager.localize("forgotPassword.message"), style: .body, color: .secondary, alignment: .center)
            Spacer()
        }
        .padding()
        .navigationTitle(localizationManager.localize("forgotPassword.title"))
    }
}

#Preview {
    ForgotPasswordView()
        .environmentObject(LocalizationManager.shared)
}
