//
//  Logger+Crashlytics.swift
//  report_lms
//

import OSLog

extension Logger {
    /// Record a non-fatal error to Crashlytics alongside the existing OSLog stream.
    /// Optional `context` keys appear on the specific crash report in Firebase console.
    ///
    /// Usage:
    ///   logger.error("Upload failed: \(error)")
    ///   logger.record(error, context: ["inspectionId": id, "fieldId": fieldId])
    func record(_ error: Error, context: [String: String] = [:]) {
        CrashlyticsLogger.record(error, context: context)
    }
}
