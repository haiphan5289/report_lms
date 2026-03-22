//
//  FieldValidation.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/1/26.
//


import Foundation
import UIKit

/// Image with associated description for inspection validation
struct InspectionImage: Identifiable, Equatable {
    let id = UUID()
    var image: UIImage
    var description: String
    
    init(image: UIImage, description: String = "") {
        self.image = image
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
