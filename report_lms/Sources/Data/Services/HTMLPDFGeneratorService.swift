//
//  HTMLPDFGeneratorService.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/4/26.
//

import Foundation
import WebKit
import UIKit
import OSLog

final class HTMLPDFGeneratorService: NSObject, PDFGeneratorType {
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.reportlms.pdf", category: "generation")
    private var pdfContinuation: CheckedContinuation<Data, Error>?
    
    // MARK: - Public Methods
    func generatePDF(detail: InspectionDetail, images: [String: [UIImage]]) async throws -> Data {
        logger.log("Starting PDF generation for inspection #\(detail.inspectionNumber)")
        
        return try await withCheckedThrowingContinuation { continuation in
            self.pdfContinuation = continuation
            
            Task { @MainActor in
                do {
                    let htmlString = generateHTML(detail: detail, images: images)
                    await convertHTMLToPDF(htmlString: htmlString)
                } catch {
                    continuation.resume(throwing: error)
                    self.pdfContinuation = nil
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func generateHTML(detail: InspectionDetail, images: [String: [UIImage]]) -> String {
        logger.log("Generating HTML template")
        
        let defectSummary = calculateDefectSummary(from: detail.sections)
        
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Inspection Report #\(detail.inspectionNumber)</title>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Helvetica Neue', Arial, sans-serif;
                    margin: 40px;
                    color: #333;
                    font-size: 14px;
                    line-height: 1.6;
                }
                
                h1 {
                    font-size: 28px;
                    color: #000;
                    margin-bottom: 10px;
                    font-weight: 700;
                }
                
                .report-date {
                    font-size: 14px;
                    color: #666;
                    margin-bottom: 30px;
                }
                
                h2 {
                    font-size: 20px;
                    color: #000;
                    margin-top: 30px;
                    margin-bottom: 15px;
                    padding-bottom: 8px;
                    border-bottom: 2px solid #007AFF;
                    font-weight: 600;
                }
                
                .summary-section {
                    margin: 30px 0;
                }
                
                .summary-title {
                    font-size: 18px;
                    font-weight: 600;
                    margin-bottom: 15px;
                    color: #000;
                }
                
                .summary-table {
                    width: 100%;
                    border-collapse: collapse;
                    margin: 20px 0;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
                }
                
                .summary-table th,
                .summary-table td {
                    border: 1px solid #ddd;
                    padding: 14px 12px;
                    text-align: center;
                    font-size: 14px;
                }
                
                .summary-table th {
                    background-color: #f5f5f7;
                    font-weight: 600;
                    color: #000;
                }
                
                .summary-table td {
                    background-color: #fff;
                }
                
                .summary-table td:first-child {
                    font-weight: 600;
                    background-color: #fafafa;
                }
                
                .defect-critical {
                    color: #d32f2f;
                    font-weight: 700;
                }
                
                .defect-major {
                    color: #f57c00;
                    font-weight: 600;
                }
                
                .defect-minor {
                    color: #fbc02d;
                    font-weight: 500;
                }
                
                .section-container {
                    margin: 30px 0;
                    page-break-inside: avoid;
                }
                
                .field-container {
                    margin: 20px 0;
                    page-break-inside: avoid;
                }
                
                .field-label {
                    font-size: 14px;
                    color: #666;
                    margin: 15px 0 10px 0;
                    font-weight: 500;
                }
                
                .image-grid {
                    display: grid;
                    grid-template-columns: repeat(2, 1fr);
                    gap: 15px;
                    margin: 15px 0;
                }
                
                .image-container {
                    position: relative;
                    overflow: hidden;
                    border-radius: 8px;
                    box-shadow: 0 2px 8px rgba(0,0,0,0.1);
                    background-color: #f9f9f9;
                }
                
                .image-container img {
                    width: 100%;
                    height: auto;
                    display: block;
                    border-radius: 8px;
                }
                
                .no-images {
                    color: #999;
                    font-style: italic;
                    padding: 10px 0;
                }
                
                .footer {
                    margin-top: 50px;
                    padding-top: 20px;
                    border-top: 1px solid #ddd;
                    text-align: center;
                    color: #666;
                    font-size: 12px;
                }
                
                @media print {
                    body {
                        margin: 20px;
                    }
                    
                    h1, h2 {
                        page-break-after: avoid;
                    }
                    
                    .section-container,
                    .field-container {
                        page-break-inside: avoid;
                    }
                    
                    .image-container {
                        page-break-inside: avoid;
                    }
                }
            </style>
        </head>
        <body>
            <h1>Báo cáo kiểm tra #\(detail.inspectionNumber)</h1>
            <div class="report-date">Ngày tạo: \(formatDate(Date()))</div>
            
            <div class="summary-section">
                <div class="summary-title">Tóm tắt lỗi</div>
                <table class="summary-table">
                    <thead>
                        <tr>
                            <th></th>
                            <th>CRITICAL</th>
                            <th>MAJOR</th>
                            <th>MINOR</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr>
                            <td>TOTAL</td>
                            <td class="defect-critical">\(defectSummary.critical)</td>
                            <td class="defect-major">\(defectSummary.major)</td>
                            <td class="defect-minor">\(defectSummary.minor)</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        """
        
        // Add sections with images
        for section in detail.sections.sorted(by: { $0.order < $1.order }) {
            html += """
            <div class="section-container">
                <h2>\(section.title)</h2>
            """
            
            for field in section.fields {
                html += "<div class='field-container'>"
                html += "<div class='field-label'>\(field.label)</div>"
                
                if let fieldImages = images[field.id], !fieldImages.isEmpty {
                    html += "<div class='image-grid'>"
                    
                    for image in fieldImages {
                        if let base64String = compressAndEncodeImage(image) {
                            html += """
                            <div class="image-container">
                                <img src="data:image/jpeg;base64,\(base64String)" alt="\(field.label)" loading="lazy">
                            </div>
                            """
                        }
                    }
                    
                    html += "</div>"
                } else {
                    html += "<div class='no-images'>Chưa có hình ảnh</div>"
                }
                
                html += "</div>"
            }
            
            html += "</div>"
        }
        
        // Footer
        html += """
            <div class="footer">
                <p>Báo cáo được tạo bởi report_lms - © 2026</p>
            </div>
        </body>
        </html>
        """
        
        logger.log("HTML template generated successfully, length: \(html.count) characters")
        return html
    }
    
    @MainActor
    private func convertHTMLToPDF(htmlString: String) async {
        logger.log("Converting HTML to PDF using WKWebView")
        
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 595, height: 842)) // A4 size
        webView.navigationDelegate = self
        webView.loadHTMLString(htmlString, baseURL: nil)
    }
    
    // MARK: - Helper Methods
    
    private func compressAndEncodeImage(_ image: UIImage) -> String? {
        // CRITICAL: Resize and compress images to prevent WKWebView crash
        // Target: Max 800px width, 40% quality = ~100-200KB per image
        
        // Step 1: Resize image
        let maxWidth: CGFloat = 800
        let resizedImage: UIImage
        
        if image.size.width > maxWidth {
            let scale = maxWidth / image.size.width
            let newHeight = image.size.height * scale
            let newSize = CGSize(width: maxWidth, height: newHeight)
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
            
            logger.debug("Image resized from \(image.size.width)x\(image.size.height) to \(newSize.width)x\(newSize.height)")
        } else {
            resizedImage = image
        }
        
        // Step 2: Compress to 40% quality for PDF (good enough for viewing)
        guard let jpegData = resizedImage.jpegData(compressionQuality: 0.4) else {
            logger.warning("Failed to compress image")
            return nil
        }
        
        // Safety check: If still too large, compress more
        let finalData: Data
        if jpegData.count > 300_000 { // 300KB threshold
            logger.warning("Image still large (\(jpegData.count) bytes), compressing to 25%")
            finalData = resizedImage.jpegData(compressionQuality: 0.25) ?? jpegData
        } else {
            finalData = jpegData
        }
        
        let base64String = finalData.base64EncodedString()
        let originalPixels = Int(image.size.width) * Int(image.size.height)
        logger.debug("Image processed: original pixels: \(originalPixels), final size: \(finalData.count) bytes")
        return base64String
    }
    
    private func calculateDefectSummary(from sections: [InspectionSection]) -> (critical: Int, major: Int, minor: Int) {
        // TODO: Implement actual defect counting logic based on your inspection data
        // For now, returning sample data
        // You should extend InspectionField with defect severity information
        return (critical: 0, major: 1, minor: 1)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        formatter.locale = Locale(identifier: "vi_VN")
        return formatter.string(from: date)
    }
}

// MARK: - WKNavigationDelegate
extension HTMLPDFGeneratorService: WKNavigationDelegate {
    @MainActor
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.log("WKWebView finished loading HTML")
        
        Task {
            do {
                let pdfConfiguration = WKPDFConfiguration()
                pdfConfiguration.rect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 size
                
                let pdfData = try await webView.pdf(configuration: pdfConfiguration)
                
                guard !pdfData.isEmpty else {
                    logger.error("PDF data is empty")
                    pdfContinuation?.resume(throwing: PDFGenerationError.noDataGenerated)
                    pdfContinuation = nil
                    return
                }
                
                logger.log("PDF generated successfully, size: \(pdfData.count) bytes")
                pdfContinuation?.resume(returning: pdfData)
                pdfContinuation = nil
            } catch {
                logger.error("PDF generation failed: \(error.localizedDescription)")
                pdfContinuation?.resume(throwing: PDFGenerationError.pdfConversionFailed)
                pdfContinuation = nil
            }
        }
    }
    
    @MainActor
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("WKWebView navigation failed: \(error.localizedDescription)")
        pdfContinuation?.resume(throwing: PDFGenerationError.webViewRenderingFailed)
        pdfContinuation = nil
    }
    
    @MainActor
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        logger.error("WKWebView provisional navigation failed: \(error.localizedDescription)")
        pdfContinuation?.resume(throwing: PDFGenerationError.webViewRenderingFailed)
        pdfContinuation = nil
    }
}
