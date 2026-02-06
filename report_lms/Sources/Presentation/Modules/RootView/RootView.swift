//
//  RootView.swift
//  report_lms
//
//  Created by AI on February 6, 2026.
//

import SwiftUI

/// Root view that determines whether to show login screen or main app based on authentication state
struct RootView: View {
    @StateObject private var userManager: UserManager
    @StateObject private var loginViewModel: LoginViewModel
    @StateObject private var lmsHomeViewModel: LMSHomeViewModel
    @State private var shouldLogout = false

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
            if userManager.isLoggedIn && !shouldLogout {
                // User is logged in, show main app
                LMSHomeView(viewModel: lmsHomeViewModel, onLogout: {
                    shouldLogout = true
                    userManager.logout()
                })
            } else {
                // User needs to login
                LoginView(viewModel: loginViewModel)
                    .onChange(of: loginViewModel.isLoginSuccessful) { oldValue, newValue in
                        if newValue {
                            shouldLogout = false
                        }
                    }
            }
        }
    }
}

#Preview {
    RootView()
}