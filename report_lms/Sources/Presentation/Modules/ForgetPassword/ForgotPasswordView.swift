//
//  ForgotPasswordView.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 21/1/26.
//

import SwiftUI

// MARK: - Forgot Password Placeholder

struct ForgotPasswordView: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "lock.rotation")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.accentColor)
                .padding(.bottom, 16)
            LMSLabel("Quên mật khẩu", style: .title, alignment: .center)
                .padding(.bottom, 8)
            LMSLabel("Tính năng đang được phát triển.", style: .body, color: .secondary, alignment: .center)
            Spacer()
        }
        .padding()
        .navigationTitle("Quên mật khẩu")
    }
}

#Preview {
    ForgotPasswordView()
}
