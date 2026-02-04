//
//  report_lmsApp.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 16/1/26.
//

import SwiftUI

@main
struct report_lmsApp: App {
    var body: some Scene {
        WindowGroup {
//            let service = AuthService()
//            let repository = AuthRepository(service: service)
//            let useCase = LoginUseCase(repository: repository)
//            let viewModel = LoginViewModel(loginUseCase: useCase)
//            LoginView(viewModel: viewModel)
            LMSHomeView(viewModel: LMSHomeViewModel())
        }
    }
}
