//
//  report_lmsApp.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 16/1/26.
//

import SwiftUI
import FirebaseCore

@main
struct report_lmsApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    private var rootView: some View {
        guard let viewModel = Container.shared.resolve(LoginViewModel.self) else {
            fatalError("Failed to resolve LoginViewModel from dependency container")
        }
        return LoginView(viewModel: viewModel)
    }
}
