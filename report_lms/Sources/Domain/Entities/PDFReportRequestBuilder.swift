//
//  PDFReportRequestBuilder.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/6/26.
//  Updated: March 6, 2026 - Changed to use Inspection instead of InspectionDetail
//

import Foundation
import UIKit

/// Solution 2: Builder Pattern
/// Provides a fluent interface for constructing PDF report requests with validation
final class PDFReportRequestBuilder {
    // MARK: - Private Properties
    private var inspection: Inspection?
    private var capturedImages: [String: [InspectionImage]] = [:]
    private var inspectorName: String?
    private var inspectionLocation: String?
    private var defectCounts: (critical: Int, major: Int, minor: Int) = (0, 0, 0)
    private var finalStatus: FinalReportStatus = .pending
    private var summaryComments: String = ""
    
    // MARK: - Builder Methods
    
    /// Set inspection
    @discardableResult
    func with(inspection: Inspection) -> Self {
        self.inspection = inspection
        return self
    }
    
    /// Set captured images
    @discardableResult
    func with(images: [String: [InspectionImage]]) -> Self {
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

    @discardableResult
    func with(defectCounts: (critical: Int, major: Int, minor: Int)) -> Self {
        self.defectCounts = defectCounts
        return self
    }

    @discardableResult
    func with(finalStatus: FinalReportStatus) -> Self {
        self.finalStatus = finalStatus
        return self
    }

    @discardableResult
    func with(summaryComments: String) -> Self {
        self.summaryComments = summaryComments
        return self
    }
    
    /// Build the final request with validation
    /// - Returns: Validated PDFReportRequest
    /// - Throws: PDFReportBuilderError if required fields are missing
    func build() throws -> PDFReportRequest {
        guard let inspectionData = inspection else {
            throw PDFReportBuilderError.missingInspection
        }
        
        guard let inspector = inspectorName, !inspector.isEmpty else {
            throw PDFReportBuilderError.missingInspectorName
        }
        
        guard let location = inspectionLocation, !location.isEmpty else {
            throw PDFReportBuilderError.missingLocation
        }
        
        return PDFReportRequest(
            inspection: inspectionData,
            capturedImages: capturedImages,
            inspectorName: inspector,
            inspectionLocation: location,
            defectCounts: defectCounts,
            finalStatus: finalStatus,
            summaryComments: summaryComments
        )
    }

    /// Reset builder to initial state
    func reset() {
        inspection = nil
        capturedImages = [:]
        inspectorName = nil
        inspectionLocation = nil
        defectCounts = (0, 0, 0)
        finalStatus = .pending
        summaryComments = ""
    }
}

// MARK: - Builder Error Types
enum PDFReportBuilderError: LocalizedError {
    case missingInspection
    case missingInspectorName
    case missingLocation
    
    var errorDescription: String? {
        switch self {
        case .missingInspection:
            return "Inspection is required"
        case .missingInspectorName:
            return "Inspector name is required"
        case .missingLocation:
            return "Inspection location is required"
        }
    }
}

// MARK: - Convenience Extensions
extension PDFReportRequestBuilder {
    /// Create builder with common defaults.
    /// Inspector name prefers the Firebase Auth display name set via the Profile screen,
    /// falling back to the Keychain-stored username for accounts that never set one.
    static func withDefaults() -> PDFReportRequestBuilder {
        let builder = PDFReportRequestBuilder()
        let displayName = Container.shared.resolve(UpdateDisplayNameUseCase.self)?.currentDisplayName()
        let fallbackName = KeychainManager.getStoredUsername() ?? "Unknown"
        builder.with(inspectorName: (displayName?.isEmpty == false ? displayName : nil) ?? fallbackName)
        return builder
    }
}

// MARK: - Usage Example
/*
 Usage in FinalReportViewModel.generateAndSendPDF():

 let request = try PDFReportRequestBuilder.withDefaults()
     .with(inspection: detail)
     .with(images: capturedPhotos)
     .with(location: location)
     .with(finalStatus: selectedStatus)
     .with(summaryComments: summaryComments)
     .build()

 let data = try await generatePDFUseCase.execute(request: request)
 */
