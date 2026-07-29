//
//  RootView.swift
//  report_lms
//
//  Created by AI on February 6, 2026.
//

import SwiftUI

struct RootView: View {
    @StateObject private var userManager: UserManager
    @StateObject private var loginViewModel: LoginViewModel
    @StateObject private var lmsHomeViewModel: LMSHomeViewModel

    init() {
        let userManager = Container.shared.resolve(UserManager.self)!
        let loginViewModel = Container.shared.resolve(LoginViewModel.self)!
        let lmsHomeViewModel = Container.shared.resolve(LMSHomeViewModel.self)!
        _userManager = StateObject(wrappedValue: userManager)
        _loginViewModel = StateObject(wrappedValue: loginViewModel)
        _lmsHomeViewModel = StateObject(wrappedValue: lmsHomeViewModel)
    }

    var body: some View {
        Group {
            if userManager.isLoggedIn {
                LMSHomeView(viewModel: lmsHomeViewModel, onLogout: {
                    loginViewModel.logout()
                })
            } else {
                LoginView(viewModel: loginViewModel)
            }
        }
        .task {
            await loginViewModel.restoreSessionIfNeeded()
        }
    }
}

#Preview {
    RootView()
}
