//
//  PDFReportRequestBuilder.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/6/26.
//

import Foundation
import UIKit

/// Solution 2: Builder Pattern
/// Provides a fluent interface for constructing PDF report requests with validation
final class PDFReportRequestBuilder {
    // MARK: - Private Properties
    private var inspectionDetail: InspectionDetail?
    private var capturedImages: [String: [UIImage]] = [:]
    private var inspectorName: String?
    private var inspectionLocation: String?
    
    // MARK: - Builder Methods
    
    /// Set inspection detail
    @discardableResult
    func with(detail: InspectionDetail) -> Self {
        self.inspectionDetail = detail
        return self
    }
    
    /// Set captured images
    @discardableResult
    func with(images: [String: [UIImage]]) -> Self {
        self.capturedImages = images
        return self
    }
    
    /// Set inspector name
    @discardableResult
    func with(inspectorName: String) -> Self {
        self.inspectorName = inspectorName
        return self
    }
    
    /// Set inspection location
    @discardableResult
    func with(location: String) -> Self {
        self.inspectionLocation = location
        return self
    }
    
    /// Build the final request with validation
    /// - Returns: Validated PDFReportRequest
    /// - Throws: PDFReportBuilderError if required fields are missing
    func build() throws -> PDFReportRequest {
        guard let detail = inspectionDetail else {
            throw PDFReportBuilderError.missingInspectionDetail
        }
        
        guard let inspector = inspectorName, !inspector.isEmpty else {
            throw PDFReportBuilderError.missingInspectorName
        }
        
        guard let location = inspectionLocation, !location.isEmpty else {
            throw PDFReportBuilderError.missingLocation
        }
        
        return PDFReportRequest(
            inspectionDetail: detail,
            capturedImages: capturedImages,
            inspectorName: inspector,
            inspectionLocation: location
        )
    }
    
    /// Build request with default values for missing optional fields
    /// - Returns: PDFReportRequest with defaults applied
    /// - Throws: Only throws if critical required fields are missing
    func buildWithDefaults() throws -> PDFReportRequest {
        guard let detail = inspectionDetail else {
            throw PDFReportBuilderError.missingInspectionDetail
        }
        
        return PDFReportRequest(
            inspectionDetail: detail,
            capturedImages: capturedImages,
            inspectorName: inspectorName ?? "Unknown Inspector",
            inspectionLocation: inspectionLocation ?? "Unknown Location"
        )
    }
    
    /// Reset builder to initial state
    func reset() {
        inspectionDetail = nil
        capturedImages = [:]
        inspectorName = nil
        inspectionLocation = nil
    }
}

// MARK: - Builder Error Types
enum PDFReportBuilderError: LocalizedError {
    case missingInspectionDetail
    case missingInspectorName
    case missingLocation
    
    var errorDescription: String? {
        switch self {
        case .missingInspectionDetail:
            return "Inspection detail is required"
        case .missingInspectorName:
            return "Inspector name is required"
        case .missingLocation:
            return "Inspection location is required"
        }
    }
}

// MARK: - Convenience Extensions
extension PDFReportRequestBuilder {
    /// Create builder with common defaults from KeychainManager
    static func withDefaults() -> PDFReportRequestBuilder {
        let builder = PDFReportRequestBuilder()
        builder.with(inspectorName: KeychainManager.getStoredUsername() ?? "Unknown")
        return builder
    }
}

// MARK: - Usage Example
/*
 Usage in FinalReportViewModel:
 
 func generateAndPreviewPDF() async {
     guard let detail = inspectionDetail else { return }
     
     do {
         let request = try PDFReportRequestBuilder()
             .with(detail: detail)
             .with(images: capturedPhotos)
             .with(inspectorName: KeychainManager.getStoredUsername() ?? "Unknown")
             .with(location: location)
             .build()
         
         let data = try await generatePDFUseCase.execute(request: request)
         pdfData = data
         isShowingPDFPreview = true
     } catch {
         errorAlertMessage = error.localizedDescription
         showErrorAlert = true
     }
 }
 
 // Or with defaults:
 let request = try PDFReportRequestBuilder.withDefaults()
     .with(detail: detail)
     .with(images: capturedPhotos)
     .with(location: location)
     .build()
 */
