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

    /// Downloads any remote images so the synchronous PDF renderer has UIImage instances.
    private func resolveRemoteImages(_ images: [String: [InspectionImage]]) async -> [String: [InspectionImage]] {
        var resolved: [String: [InspectionImage]] = [:]
        await withTaskGroup(of: (String, [InspectionImage]).self) { group in
            for (fieldId, fieldImages) in images {
                group.addTask {
                    var resolvedField: [InspectionImage] = []
                    for img in fieldImages {
                        if img.isRemote, let url = img.remoteURL {
                            // ✅ Use ImageCacheActor for cached download
                            if let cachedImage = await ImageCacheActor.shared.image(for: url) {
                                resolvedField.append(InspectionImage(image: cachedImage, description: img.description))
                            } else if let (data, _) = try? await URLSession.shared.data(from: url),
                                      let uiImage = UIImage(data: data) {
                                // Store in cache for future use
                                await ImageCacheActor.shared.store(uiImage, for: url)
                                resolvedField.append(InspectionImage(image: uiImage, description: img.description))
                            }
                            // Skip images that fail to download — don't break PDF for one bad image
                        } else {
                            resolvedField.append(img)
                        }
                    }
                    return (fieldId, resolvedField)
                }
            }
            for await (fieldId, fieldImages) in group {
                resolved[fieldId] = fieldImages
            }
        }
        return resolved
    }
    
    // MARK: - Builder Pattern Support
    
    /// Execute PDF generation with a unified request object (Builder Pattern)
    /// - Parameter request: Complete PDF generation request containing all required data
    /// - Returns: PDF data ready for sharing or saving
    /// - Throws: PDFReportRequestError if validation fails
    func execute(request: PDFReportRequest) async throws -> Data {
        logger.log("Executing PDF generation with request model for inspection #\(request.inspection.inspectionNumber)")
        
        // Validate request
        if let error = request.validationError {
            logger.error("Request validation failed: \(error.localizedDescription)")
            throw error
        }
        
        // Resolve remote images before the synchronous PDF renderer runs
        let resolvedImages = await resolveRemoteImages(request.capturedImages)

        let pdfData = try await pdfGenerator.generatePDF(
            detail: request.inspection,
            images: resolvedImages,
            inspectorName: request.inspectorName,
            location: request.inspectionLocation,
            defectCounts: request.defectCounts,
            finalStatus: request.finalStatus,
            summaryComments: request.summaryComments
        )
        
        logger.log("PDF generated successfully from request, size: \(pdfData.count) bytes")
        return pdfData
    }
}
