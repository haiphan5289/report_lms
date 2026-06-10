//
//  report_lmsApp.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 16/1/26.
//

import SwiftUI
import FirebaseCore
import OSLog

@main
struct report_lmsApp: App {
    @StateObject private var localizationManager = LocalizationManager.shared

    init() {
        FirebaseApp.configure()
        
        // Load inspection cache then retry any interrupted uploads
        Task {
            let logger = Logger(subsystem: "com.reportlms.app", category: "lifecycle")
            do {
                if let storageService = Container.shared.resolve(InspectionStorageServiceType.self) {
                    try await storageService.loadCache()
                    logger.log("Inspection cache loaded successfully")
                } else {
                    logger.error("Failed to resolve InspectionStorageServiceType")
                }
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
