//
//  report_lmsApp.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 16/1/26.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseCrashlytics
import OSLog

@main
struct report_lmsApp: App {
    @StateObject private var localizationManager = LocalizationManager.shared

    init() {
        FirebaseApp.configure()
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        // Only a persisted Firebase Auth session (app relaunch while already logged in) is
        // handled here. A fresh login loads its own company-scoped cache from LoginViewModel
        // once the user submits credentials — see loadCompanyScopedData(userId:) there.
        guard let uid = Auth.auth().currentUser?.uid else { return }

        Task {
            let logger = Logger(subsystem: "com.reportlms.app", category: "lifecycle")
            guard
                let storageService = Container.shared.resolve(InspectionStorageServiceType.self),
                let fetchUserProfileUseCase = Container.shared.resolve(FetchUserProfileUseCase.self),
                let userManager = Container.shared.resolve(UserManager.self)
            else {
                logger.error("Failed to resolve dependencies for company-scoped cache load")
                return
            }

            do {
                guard let profile = try await fetchUserProfileUseCase.execute(userId: uid) else {
                    logger.error("No company profile found for persisted session \(uid) — logging out")
                    await MainActor.run { userManager.logout() }
                    return
                }
                await MainActor.run { userManager.setCompany(profile.companyId) }
                try await storageService.loadCache(companyId: profile.companyId)
                logger.log("Inspection cache loaded successfully for company \(profile.companyId)")
            } catch {
                logger.error("Failed to load inspection cache: \(error.localizedDescription)")
            }
            // Retry uploads after cache is ready so getInspection(by:) returns fresh data
            PendingUploadRetryService.shared.retryAllPendingUploads()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(localizationManager)
        }
    }
}
