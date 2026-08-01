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
        // handled here. A fresh login loads its own cache from LoginViewModel once the user
        // submits credentials — see loadInspectionCache(userId:) there.
        guard let uid = Auth.auth().currentUser?.uid else { return }

        Task {
            let logger = Logger(subsystem: "com.reportlms.app", category: "lifecycle")
            guard let storageService = Container.shared.resolve(InspectionStorageServiceType.self) else {
                logger.error("Failed to resolve InspectionStorageServiceType for cache load")
                return
            }

            do {
                try await storageService.loadCache(inspectorId: uid)
                logger.log("Inspection cache loaded successfully for inspector \(uid)")
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
