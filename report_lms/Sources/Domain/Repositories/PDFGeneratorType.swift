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
    func generatePDF(
        detail: Inspection,
        images: [String: [InspectionImage]],
        inspectorName: String,
        location: String,
        defectCounts: (critical: Int, major: Int, minor: Int),
        finalStatus: FinalReportStatus,
        summaryComments: String
    ) async throws -> Data
}
