//
//  ErrorItem.swift
//  report_lms
//
//  Created by GitHub Copilot on 27/1/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import Foundation
import UIKit

// MARK: - Error Item Entity (Stub - TODO: Implement properly)
struct ErrorItem: Identifiable {
    let id: String
    let headerText: String
    let defectDescription: String
    let severity: SeverityLevel
    let defectType: DefectType
    let timestamp: Date
    let image: UIImage
    let affectedCount: Int
    let actualMeasurement: Double
    let maxAllowed: Double
    
    init(
        id: String = UUID().uuidString,
        headerText: String = "Error Header",
        defectDescription: String = "Defect Description",
        severity: SeverityLevel = .low,
        defectType: DefectType = .crack,
        timestamp: Date = Date(),
        image: UIImage = UIImage(),
        affectedCount: Int = 0,
        actualMeasurement: Double = 0.0,
        maxAllowed: Double = 0.0
    ) {
        self.id = id
        self.headerText = headerText
        self.defectDescription = defectDescription
        self.severity = severity
        self.defectType = defectType
        self.timestamp = timestamp
        self.image = image
        self.affectedCount = affectedCount
        self.actualMeasurement = actualMeasurement
        self.maxAllowed = maxAllowed
    }
}

// MARK: - Severity Level
enum SeverityLevel: String, Codable, CaseIterable {
    case low = "Thấp"
    case medium = "Trung bình"
    case high = "Cao"
    case critical = "Nghiêm trọng"
    
    var displayName: String {
        self.rawValue
    }
}

// MARK: - Defect Type
enum DefectType: String, Codable, CaseIterable {
    case crack = "Vết nứt"
    case corrosion = "Ăn mòn"
    case deformation = "Biến dạng"
    case damage = "Hư hỏng"
    case other = "Khác"
    
    var displayName: String {
        self.rawValue
    }
}
