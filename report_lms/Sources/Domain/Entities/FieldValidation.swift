//
//  FieldValidation.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/1/26.
//


import Foundation
import UIKit

/// Image with associated description for inspection validation.
/// Supports two sources: local (camera capture) and remote (Firebase Storage URL).
struct InspectionImage: Identifiable, Equatable {
    let id = UUID()
    /// Non-nil for locally captured photos. Empty `UIImage()` placeholder for remote images.
    var image: UIImage
    /// Non-nil when the image originates from Firebase Storage — used by `AsyncImage` in views.
    var remoteURL: URL?
    var description: String

    /// True when this image is loaded from a remote URL rather than captured locally.
    var isRemote: Bool { remoteURL != nil }

    /// Local (camera) image — backward-compatible init.
    init(image: UIImage, description: String = "") {
        self.image = image
        self.remoteURL = nil
        self.description = description
    }

    /// Remote image from Firebase Storage. Views use `AsyncImage(url: remoteURL)`.
    init(remoteURL: URL, description: String = "") {
        self.image = UIImage()   // placeholder; never drawn directly
        self.remoteURL = remoteURL
        self.description = description
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
