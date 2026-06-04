//
//  FeatureFlags.swift
//  report_lms
//

import Foundation

enum FeatureFlags {
    /// Enables server-side report delivery via Firestore queue + Cloud Functions.
    /// Set USE_FIREBASE_DELIVERY=1 in the Xcode scheme environment to enable in DEBUG.
    /// Flip to `true` in the else branch once Cloud Function is deployed to production.
    static var useFirebaseReportDelivery: Bool { true } // TODO: revert before commit
}
