//
//  CrashlyticsLogger.swift
//  report_lms
//

import Foundation
import FirebaseCrashlytics

/// Central Crashlytics wrapper. All non-fatal errors and custom keys go through here.
///
/// Call sites use `Logger.record(_:context:)` (see `Logger+Crashlytics.swift`).
/// This enum is the only file that imports FirebaseCrashlytics.
enum CrashlyticsLogger {

    /// Record a non-fatal error. Optional `context` keys are set before recording
    /// so they appear on that specific crash report in the Firebase console.
    static func record(_ error: Error, context: [String: String] = [:]) {
        let instance = Crashlytics.crashlytics()
        for (key, value) in context {
            instance.setCustomValue(value, forKey: key)
        }
        instance.record(error: error)
    }

    /// Persist a custom key visible on every subsequent crash/non-fatal report.
    static func setKey(_ key: String, value: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    /// Set the Crashlytics user identifier (shown in the Firebase console per-crash).
    static func setUserID(_ userID: String) {
        Crashlytics.crashlytics().setUserID(userID)
    }

    /// Clear user identity and sensitive custom keys on logout.
    static func clearUser() {
        let instance = Crashlytics.crashlytics()
        instance.setUserID("")
        instance.setCustomValue("", forKey: "username")
    }
}
