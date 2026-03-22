//
//  GenerateHTMLPDFReportUseCase.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/4/26.
//

import Foundation
import UIKit
import OSLog

/// Use case for generating PDF reports from inspection data
final class GenerateHTMLPDFReportUseCase {
    // MARK: - Properties
    private let pdfGenerator: PDFGeneratorType
    private let logger = Logger(subsystem: "com.reportlms.usecases", category: "pdf")
    
    // MARK: - Initialization
    init(pdfGenerator: PDFGeneratorType) {
        self.pdfGenerator = pdfGenerator
    }
    
    // MARK: - Public Methods
    
    /// Execute PDF generation for an inspection
    /// - Parameters:
    ///   - detail: The inspection detail containing all sections and fields
    ///   - images: Dictionary mapping field IDs to their captured images
    ///   - inspectorName: Name of the inspector
    ///   - location: Inspection location
    /// - Returns: PDF data ready for sharing or saving
    /// - Throws: PDFGenerationError if generation fails
    func execute(
        detail: Inspection,
        images: [String: [InspectionImage]],
        inspectorName: String,
        location: String
    ) async throws -> Data {
        logger.log("Executing PDF generation use case for inspection #\(detail.inspectionNumber)")
        
        // Validate input
        guard !detail.sections.isEmpty else {
            logger.error("Inspection has no sections")
            throw PDFGenerationError.invalidInspectionData
        }
        
        // Generate PDF
        do {
            let pdfData = try await pdfGenerator.generatePDF(
                detail: detail,
                images: images,
                inspectorName: inspectorName,
                location: location
            )
            
            logger.log("PDF generation completed successfully, size: \(pdfData.count) bytes")
            return pdfData
        } catch {
            logger.error("PDF generation failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Builder Pattern Support
    
    /// Execute PDF generation with a unified request object (Builder Pattern)
    /// - Parameter request: Complete PDF generation request containing all required data
    /// - Returns: PDF data ready for sharing or saving
    /// - Throws: PDFGenerationError or PDFReportRequestError if generation/validation fails
    func execute(request: PDFReportRequest) async throws -> Data {
        logger.log("Executing PDF generation with request model for inspection #\(request.inspection.inspectionNumber)")
        
        // Validate request
        if let error = request.validationError {
            logger.error("Request validation failed: \(error.localizedDescription)")
            throw error
        }
        
        // Generate PDF using validated request data
        let pdfData = try await pdfGenerator.generatePDF(
            detail: request.inspection,
            images: request.capturedImages,
            inspectorName: request.inspectorName,
            location: request.inspectionLocation
        )
        
        logger.log("PDF generated successfully from request, size: \(pdfData.count) bytes")
        return pdfData
    }
}
