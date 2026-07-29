//
//  FieldValidation.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/1/26.
//


import Foundation
import UIKit

/// Image with associated description for inspection validation.
/// Supports three sources:
///   - Local capture: thumbnail in RAM + full-res at fileURL on disk
///   - Remote: remoteURL pointing to Firebase Storage (no UIImage in RAM)
///   - Legacy: UIImage passed directly (PDF, HTML generation) stored as thumbnail
struct InspectionImage: Identifiable, Equatable {
    let id: UUID
    /// Display-only thumbnail (~800px, ~2 MB). nil for remote-only images.
    var thumbnail: UIImage?
    /// Absolute path to full-resolution JPEG on disk. nil for remote/legacy images.
    var fileURL: URL?
    /// Firebase Storage URL. Non-nil after successful upload or for pre-existing remote images.
    var remoteURL: URL?
    var description: String
    /// User-entered size measurement in millimeters, as raw text (e.g. "25.4"). Empty when not set.
    var measurementMM: String

    var isRemote: Bool { remoteURL != nil }
    var hasLocalFile: Bool { fileURL != nil }

    /// Backward-compatible accessor. Returns thumbnail for display.
    /// Upload and edit flows must load full-res from fileURL instead.
    var image: UIImage { thumbnail ?? UIImage() }

    /// Millimeter value parsed from `measurementMM`, or nil if empty/invalid.
    var measurementMMValue: Double? {
        Double(measurementMM.replacingOccurrences(of: ",", with: "."))
    }

    /// Equivalent measurement in inches (1 inch = 25.4 mm), unrounded. nil if `measurementMM` is empty/invalid.
    var measurementInchValue: Double? {
        measurementMMValue.map { $0 / 25.4 }
    }

    /// Primary init for camera captures: thumbnail in RAM, full-res at fileURL on disk.
    init(fileURL: URL, thumbnail: UIImage, description: String = "", measurementMM: String = "") {
        self.id = UUID()
        self.fileURL = fileURL
        self.thumbnail = thumbnail
        self.remoteURL = nil
        self.description = description
        self.measurementMM = measurementMM
    }

    /// Remote image from Firebase Storage. Views render via AsyncImage(url: remoteURL).
    init(remoteURL: URL, description: String = "", measurementMM: String = "") {
        self.id = UUID()
        self.thumbnail = nil
        self.fileURL = nil
        self.remoteURL = remoteURL
        self.description = description
        self.measurementMM = measurementMM
    }

    /// Legacy init for non-capture callers (PDF, HTML report, unit tests).
    /// Stores the UIImage directly as thumbnail — no fileURL on disk.
    init(image: UIImage, description: String = "", measurementMM: String = "") {
        self.id = UUID()
        self.thumbnail = image
        self.fileURL = nil
        self.remoteURL = nil
        self.description = description
        self.measurementMM = measurementMM
    }
}

/// Field validation result with status, comments, and images
struct FieldValidation: Identifiable {
    let id: String // fieldId
    var status: ValidationStatus
    var comments: String
    var images: [InspectionImage]
    let lastUpdated: Date
    
    init(
        id: String,
        status: ValidationStatus = .pending,
        comments: String = "",
        images: [InspectionImage] = [],
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.status = status
        self.comments = comments
        self.images = images
        self.lastUpdated = lastUpdated
    }
}
