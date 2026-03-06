//
//  PDFGeneratorType.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/4/26.
//

import Foundation
import UIKit

/// Protocol defining PDF generation capabilities
protocol PDFGeneratorType {
    /// Generate PDF from inspection detail and captured images
    /// - Parameters:
    ///   - detail: The inspection detail containing sections and fields
    ///   - images: Dictionary mapping field IDs to their captured images
    ///   - inspectorName: Name of the inspector
    ///   - location: Inspection location
    /// - Returns: PDF data
    /// - Throws: PDFGenerationError if generation fails
    func generatePDF(
        detail: InspectionDetail,
        images: [String: [UIImage]],
        inspectorName: String,
        location: String
    ) async throws -> Data
}

/// Errors that can occur during PDF generation
enum PDFGenerationError: LocalizedError {
    case htmlGenerationFailed
    case webViewRenderingFailed
    case pdfConversionFailed
    case noDataGenerated
    case invalidInspectionData
    
    var errorDescription: String? {
        switch self {
        case .htmlGenerationFailed:
            return "Không thể tạo HTML template"
        case .webViewRenderingFailed:
            return "Không thể render HTML"
        case .pdfConversionFailed:
            return "Không thể chuyển đổi sang PDF"
        case .noDataGenerated:
            return "Không có dữ liệu PDF được tạo"
        case .invalidInspectionData:
            return "Dữ liệu kiểm tra không hợp lệ"
        }
    }
}
