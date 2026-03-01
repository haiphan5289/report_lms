//
//  FieldValidation.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/1/26.
//

import Foundation
import UIKit

/// Field validation result with status, comments, and images
struct FieldValidation: Identifiable {
    let id: String // fieldId
    var status: ValidationStatus
    var comments: String
    var images: [UIImage]
    let lastUpdated: Date
    
    init(
        id: String,
        status: ValidationStatus = .pending,
        comments: String = "",
        images: [UIImage] = [],
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.status = status
        self.comments = comments
        self.images = images
        self.lastUpdated = lastUpdated
    }
}
