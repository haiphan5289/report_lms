//
//  PDFReportRequest.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/6/26.
//  Updated: March 6, 2026 - Changed to use Inspection instead of InspectionDetail
//

import Foundation
import UIKit

/// Solution 1: Single DTO (Data Transfer Object) Pattern
/// A unified model that encapsulates all parameters for PDF generation
struct PDFReportRequest {
    // MARK: - Properties
    let inspection: Inspection
    let capturedImages: [String: [InspectionImage]]
    let inspectorName: String
    let inspectionLocation: String
    let defectCounts: (critical: Int, major: Int, minor: Int)
    
    // MARK: - Validation
    
    /// Validates that all required data is present
    var isValid: Bool {
        !inspection.sections.isEmpty &&
        !inspectorName.isEmpty &&
        !inspectionLocation.isEmpty
    }
    
    /// Validation error if data is invalid
    var validationError: PDFReportRequestError? {
        if inspection.sections.isEmpty {
            return .noInspectionSections
        }
        if inspectorName.isEmpty {
            return .missingInspectorName
        }
        if inspectionLocation.isEmpty {
            return .missingLocation
        }
        return nil
    }
}

// MARK: - Error Types
enum PDFReportRequestError: LocalizedError {
    case noInspectionSections
    case missingInspectorName
    case missingLocation
    
    var errorDescription: String? {
        switch self {
        case .noInspectionSections:
            return "Inspection has no sections"
        case .missingInspectorName:
            return "Inspector name is required"
        case .missingLocation:
            return "Inspection location is required"
        }
    }
}

// MARK: - Preview Helpers
extension PDFReportRequest {
    static func mock() -> PDFReportRequest {
        PDFReportRequest(
            inspection: .mock(inspectionId: "1", inspectionNumber: "001"),
            capturedImages: [:],
            inspectorName: "John Doe",
            inspectionLocation: "Factory A",
            defectCounts: (critical: 0, major: 0, minor: 0)
        )
    }
}
