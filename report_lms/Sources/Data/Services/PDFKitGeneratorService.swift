//
//  PDFKitGeneratorService.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/4/26.
//

import Foundation
import UIKit
import OSLog

/// Native iOS PDF generation using UIGraphicsPDFRenderer (Solution 3)
/// Provides highest quality, best performance, and unlimited image capacity
final class PDFKitGeneratorService: PDFGeneratorType {
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.reportlms.pdf", category: "pdfkit")
    
    // MARK: - Layout Constants
    private enum Layout {
        static let pageWidth: CGFloat = 595.2 // A4 width in points (210mm)
        static let pageHeight: CGFloat = 841.8 // A4 height in points (297mm)
        static let margin: CGFloat = 40
        static let contentWidth: CGFloat = pageWidth - (2 * margin)
        
        // Typography
        static let titleFontSize: CGFloat = 24
        static let headingFontSize: CGFloat = 18
        static let subheadingFontSize: CGFloat = 14
        static let bodyFontSize: CGFloat = 12
        static let captionFontSize: CGFloat = 10
        
        // Spacing
        static let sectionSpacing: CGFloat = 24
        static let fieldSpacing: CGFloat = 16
        static let imageSpacing: CGFloat = 12
        
        // Images
        static let imagesPerRow: Int = 2
        static let imageWidth: CGFloat = (contentWidth - imageSpacing) / 2
        static let imageHeight: CGFloat = imageWidth * 0.75 // 4:3 aspect ratio
        
        // Table
        static let tableRowHeight: CGFloat = 32
        static let tableBorderWidth: CGFloat = 1
    }
    
    // MARK: - Public Methods
    func generatePDF(
        detail: Inspection,
        images: [String: [InspectionImage]],
        inspectorName: String,
        location: String,
        defectCounts: (critical: Int, major: Int, minor: Int)
    ) async throws -> Data {
        logger.log("Starting PDFKit native generation for inspection #\(detail.inspectionNumber)")
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "report_lms",
            kCGPDFContextTitle as String: "Inspection Report \(detail.inspectionNumber)",
            kCGPDFContextAuthor as String: "LMS Inspection System"
        ]
        
        let pageRect = CGRect(x: 0, y: 0, width: Layout.pageWidth, height: Layout.pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            var yPosition: CGFloat = Layout.margin
            
            context.beginPage()
            
            // Header fields (new feature)
            yPosition = drawHeaderFields(
                inspectorName: inspectorName,
                inspectionDate: Date(),
                sampleQuantity: "1",
                orderQuantity: "\(detail.orderQuantity)",
                location: location,
                formName: "Final CheckList",
                expectedDate: Date(),
                samplingMethod: "100% inspection",
                factoryName: detail.factoryName,
                at: yPosition
            )
            yPosition += Layout.sectionSpacing
            
            // Page 1: Title and Summary
            yPosition = drawTitle(detail.inspectionNumber, at: yPosition)
            yPosition = drawDate(at: yPosition)
            yPosition += Layout.sectionSpacing
            
            yPosition = drawSummarySection(defectCounts: defectCounts, at: yPosition)
            yPosition += Layout.sectionSpacing
            
            // Sections with images
            for section in detail.sections.sorted(by: { $0.order < $1.order }) {
                // Check if need new page for section header
                if yPosition > Layout.pageHeight - 150 {
                    context.beginPage()
                    yPosition = Layout.margin
                }
                
                yPosition = drawSectionHeader(section.title, at: yPosition)
                yPosition += Layout.fieldSpacing
                
                // Draw fields
                for field in section.fields {
                    if let fieldImages = images[field.id], !fieldImages.isEmpty {
                        // Check if need new page for field
                        if yPosition > Layout.pageHeight - 200 {
                            context.beginPage()
                            yPosition = Layout.margin
                        }
                        
                        yPosition = drawFieldLabel(field.label, at: yPosition)
                        yPosition = drawFieldImages(fieldImages, at: yPosition, context: context)
                        yPosition += Layout.fieldSpacing
                    }
                }
                
                yPosition += Layout.sectionSpacing
            }
            
            // Footer on last page
            drawFooter(at: Layout.pageHeight - Layout.margin + 10)
        }
        
        logger.log("PDFKit generation completed, size: \(data.count) bytes")
        return data
    }
    
    // MARK: - Drawing Methods
    
    private func drawTitle(_ inspectionNumber: String, at yPosition: CGFloat) -> CGFloat {
        let title = "Báo cáo kiểm tra #\(inspectionNumber)"
        let font = UIFont.boldSystemFont(ofSize: Layout.titleFontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        
        let titleSize = title.size(withAttributes: attributes)
        let titleRect = CGRect(
            x: Layout.margin,
            y: yPosition,
            width: Layout.contentWidth,
            height: titleSize.height
        )
        
        title.draw(in: titleRect, withAttributes: attributes)
        return yPosition + titleSize.height + 8
    }
    
    private func drawDate(at yPosition: CGFloat) -> CGFloat {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        dateFormatter.locale = Locale(identifier: "vi_VN")
        
        let dateString = "Ngày tạo: \(dateFormatter.string(from: Date()))"
        let font = UIFont.systemFont(ofSize: Layout.bodyFontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.gray
        ]
        
        let dateSize = dateString.size(withAttributes: attributes)
        let dateRect = CGRect(
            x: Layout.margin,
            y: yPosition,
            width: Layout.contentWidth,
            height: dateSize.height
        )
        
        dateString.draw(in: dateRect, withAttributes: attributes)
        return yPosition + dateSize.height
    }
    
    private func drawHeaderFields(
        inspectorName: String,
        inspectionDate: Date,
        sampleQuantity: String,
        orderQuantity: String,
        location: String,
        formName: String,
        expectedDate: Date,
        samplingMethod: String,
        factoryName: String,
        at yPosition: CGFloat
    ) -> CGFloat {
        var currentY = yPosition
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        dateFormatter.locale = Locale(identifier: "vi_VN")
        
        let inspectionDateFormatter = DateFormatter()
        inspectionDateFormatter.dateFormat = "dd/MM/yyyy"
        inspectionDateFormatter.locale = Locale(identifier: "vi_VN")
        
        let labelFont = UIFont.systemFont(ofSize: Layout.bodyFontSize)
        let valueFont = UIFont.boldSystemFont(ofSize: Layout.bodyFontSize)
        
        // Row 1: Người kiểm tra & Ngày kiểm tra
        currentY = drawHeaderRow(
            leftLabel: "Người kiểm tra:",
            leftValue: inspectorName,
            rightLabel: "Ngày kiểm tra:",
            rightValue: inspectionDateFormatter.string(from: inspectionDate),
            at: currentY,
            labelFont: labelFont,
            valueFont: valueFont
        )
        
        // Row 2: Số lượng mẫu & Số lượng đơn hàng
        currentY = drawHeaderRow(
            leftLabel: "Số lượng mẫu:",
            leftValue: sampleQuantity,
            rightLabel: "Số lượng đơn hàng:",
            rightValue: orderQuantity,
            at: currentY,
            labelFont: labelFont,
            valueFont: valueFont
        )
        
        // Row 3: Vị trí & Tên biểu mẫu
        currentY = drawHeaderRow(
            leftLabel: "Vị trí:",
            leftValue: location.isEmpty ? "N/A" : location,
            rightLabel: "Tên biểu mẫu:",
            rightValue: formName,
            at: currentY,
            labelFont: labelFont,
            valueFont: valueFont
        )
        
        // Row 4: Ngày dự kiến & Phương pháp lấy mẫu
        currentY = drawHeaderRow(
            leftLabel: "Ngày dự kiến:",
            leftValue: dateFormatter.string(from: expectedDate),
            rightLabel: "Phương pháp lấy mẫu:",
            rightValue: samplingMethod,
            at: currentY,
            labelFont: labelFont,
            valueFont: valueFont
        )
        
        // Row 5: Tên nhà máy (full width)
        let factoryLabel = "Tên nhà máy:"
        let factoryAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.black
        ]
        let factoryLabelSize = factoryLabel.size(withAttributes: factoryAttributes)
        factoryLabel.draw(
            at: CGPoint(x: Layout.margin, y: currentY),
            withAttributes: factoryAttributes
        )
        
        let factoryValueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: UIColor.black
        ]
        factoryName.draw(
            at: CGPoint(x: Layout.margin + factoryLabelSize.width + 8, y: currentY),
            withAttributes: factoryValueAttributes
        )
        
        currentY += factoryLabelSize.height + 8
        
        // Draw separator line
        let separatorY = currentY + 8
        let separatorPath = UIBezierPath()
        separatorPath.move(to: CGPoint(x: Layout.margin, y: separatorY))
        separatorPath.addLine(to: CGPoint(x: Layout.margin + Layout.contentWidth, y: separatorY))
        UIColor.lightGray.setStroke()
        separatorPath.lineWidth = 1
        separatorPath.stroke()
        
        return separatorY + 8
    }
    
    private func drawHeaderRow(
        leftLabel: String,
        leftValue: String,
        rightLabel: String,
        rightValue: String,
        at yPosition: CGFloat,
        labelFont: UIFont,
        valueFont: UIFont
    ) -> CGFloat {
        let halfWidth = Layout.contentWidth / 2
        let dashesAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.lightGray
        ]
        
        // Left side
        let leftLabelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.black
        ]
        let leftValueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: UIColor.black
        ]
        
        var xPosition: CGFloat = Layout.margin
        leftLabel.draw(at: CGPoint(x: xPosition, y: yPosition), withAttributes: leftLabelAttributes)
        xPosition += leftLabel.size(withAttributes: leftLabelAttributes).width + 4
        
        leftValue.draw(at: CGPoint(x: xPosition, y: yPosition), withAttributes: leftValueAttributes)
        xPosition += leftValue.size(withAttributes: leftValueAttributes).width + 8
        
        // Dashes separator
        let dashesText = "---------"
        dashesText.draw(at: CGPoint(x: xPosition, y: yPosition), withAttributes: dashesAttributes)
        
        // Right side
        xPosition = Layout.margin + halfWidth + 20
        rightLabel.draw(at: CGPoint(x: xPosition, y: yPosition), withAttributes: leftLabelAttributes)
        xPosition += rightLabel.size(withAttributes: leftLabelAttributes).width + 4
        
        rightValue.draw(at: CGPoint(x: xPosition, y: yPosition), withAttributes: leftValueAttributes)
        
        let lineHeight = max(
            leftLabel.size(withAttributes: leftLabelAttributes).height,
            rightLabel.size(withAttributes: leftLabelAttributes).height
        )
        
        return yPosition + lineHeight + 6
    }
    
    private func drawSummarySection(defectCounts: (critical: Int, major: Int, minor: Int), at yPosition: CGFloat) -> CGFloat {
        var currentY = yPosition

        let sectionTitle = "Tóm tắt lỗi"
        let titleFont = UIFont.boldSystemFont(ofSize: Layout.subheadingFontSize)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]

        let titleSize = sectionTitle.size(withAttributes: titleAttributes)
        sectionTitle.draw(at: CGPoint(x: Layout.margin, y: currentY), withAttributes: titleAttributes)
        currentY += titleSize.height + 12

        currentY = drawSummaryTable(
            critical: defectCounts.critical,
            major: defectCounts.major,
            minor: defectCounts.minor,
            at: currentY
        )
        return currentY
    }
    
    private func drawSummaryTable(critical: Int, major: Int, minor: Int, at yPosition: CGFloat) -> CGFloat {
        let columnWidth = Layout.contentWidth / 4
        let rowHeight = Layout.tableRowHeight
        var currentY = yPosition
        
        let headerFont = UIFont.boldSystemFont(ofSize: Layout.bodyFontSize)
        let cellFont = UIFont.systemFont(ofSize: Layout.bodyFontSize)
        
        // Header row
        let headers = ["", "CRITICAL", "MAJOR", "MINOR"]
        for (index, header) in headers.enumerated() {
            let cellRect = CGRect(
                x: Layout.margin + CGFloat(index) * columnWidth,
                y: currentY,
                width: columnWidth,
                height: rowHeight
            )
            
            // Background
            UIColor(white: 0.95, alpha: 1.0).setFill()
            UIBezierPath(rect: cellRect).fill()
            
            // Border
            UIColor.black.setStroke()
            let borderPath = UIBezierPath(rect: cellRect)
            borderPath.lineWidth = Layout.tableBorderWidth
            borderPath.stroke()
            
            // Text
            let attributes: [NSAttributedString.Key: Any] = [
                .font: headerFont,
                .foregroundColor: UIColor.black
            ]
            let textSize = header.size(withAttributes: attributes)
            let textRect = CGRect(
                x: cellRect.origin.x + (cellRect.width - textSize.width) / 2,
                y: cellRect.origin.y + (cellRect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            header.draw(in: textRect, withAttributes: attributes)
        }
        currentY += rowHeight
        
        // Data row
        let values = ["TOTAL", "\(critical)", "\(major)", "\(minor)"]
        let colors: [UIColor] = [.black, .systemRed, .systemOrange, .systemYellow]
        
        for (index, value) in values.enumerated() {
            let cellRect = CGRect(
                x: Layout.margin + CGFloat(index) * columnWidth,
                y: currentY,
                width: columnWidth,
                height: rowHeight
            )
            
            // Background
            if index == 0 {
                UIColor(white: 0.97, alpha: 1.0).setFill()
                UIBezierPath(rect: cellRect).fill()
            }
            
            // Border
            UIColor.black.setStroke()
            let borderPath = UIBezierPath(rect: cellRect)
            borderPath.lineWidth = Layout.tableBorderWidth
            borderPath.stroke()
            
            // Text
            let font = index == 0 ? headerFont : cellFont
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: colors[index]
            ]
            let textSize = value.size(withAttributes: attributes)
            let textRect = CGRect(
                x: cellRect.origin.x + (cellRect.width - textSize.width) / 2,
                y: cellRect.origin.y + (cellRect.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            value.draw(in: textRect, withAttributes: attributes)
        }
        currentY += rowHeight
        
        return currentY
    }
    
    private func drawSectionHeader(_ title: String, at yPosition: CGFloat) -> CGFloat {
        let font = UIFont.boldSystemFont(ofSize: Layout.headingFontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        
        // Draw text
        let textSize = title.size(withAttributes: attributes)
        title.draw(
            at: CGPoint(x: Layout.margin, y: yPosition),
            withAttributes: attributes
        )
        
        // Draw underline
        let underlineY = yPosition + textSize.height + 4
        let underlinePath = UIBezierPath()
        underlinePath.move(to: CGPoint(x: Layout.margin, y: underlineY))
        underlinePath.addLine(to: CGPoint(x: Layout.margin + Layout.contentWidth, y: underlineY))
        UIColor.systemBlue.setStroke()
        underlinePath.lineWidth = 2
        underlinePath.stroke()
        
        return underlineY + 4
    }
    
    private func drawFieldLabel(_ label: String, at yPosition: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: Layout.subheadingFontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.darkGray
        ]
        
        let labelSize = label.size(withAttributes: attributes)
        label.draw(
            at: CGPoint(x: Layout.margin, y: yPosition),
            withAttributes: attributes
        )
        
        return yPosition + labelSize.height + 8
    }
    
    private func drawFieldImages(_ images: [InspectionImage], at yPosition: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        var currentY = yPosition
        var currentColumn = 0
        
        logger.log("Drawing \(images.count) images for field")
        
        for (index, inspectionImage) in images.enumerated() {
            let image = inspectionImage.image
            // Check if need new page
            if currentY + Layout.imageHeight > Layout.pageHeight - Layout.margin {
                context.beginPage()
                currentY = Layout.margin
                currentColumn = 0
            }
            
            let xPosition = Layout.margin + CGFloat(currentColumn) * (Layout.imageWidth + Layout.imageSpacing)
            let imageRect = CGRect(
                x: xPosition,
                y: currentY,
                width: Layout.imageWidth,
                height: Layout.imageHeight
            )
            
            logger.log("Drawing image #\(index + 1) at position (\(xPosition), \(currentY))")
            
            // Save graphics state before clipping
            context.cgContext.saveGState()
            
            // Draw shadow
            let shadowPath = UIBezierPath(roundedRect: imageRect, cornerRadius: 6)
            UIColor.black.withAlphaComponent(0.1).setFill()
            shadowPath.fill()
            
            // Draw image with slight inset for shadow effect
            let imageInsetRect = imageRect.insetBy(dx: 1, dy: 1)
            
            // Resize image for optimal quality (2x rendering size)
            let targetSize = CGSize(
                width: Layout.imageWidth * 2,
                height: Layout.imageHeight * 2
            )
            let resizedImage = resizeImage(image, to: targetSize)
            
            // Draw with rounded corners
            let imagePath = UIBezierPath(roundedRect: imageInsetRect, cornerRadius: 6)
            imagePath.addClip()
            resizedImage.draw(in: imageInsetRect)
            
            // Restore graphics state after clipping
            context.cgContext.restoreGState()
            
            // Draw border
            UIColor.lightGray.setStroke()
            let borderPath = UIBezierPath(roundedRect: imageInsetRect, cornerRadius: 6)
            borderPath.lineWidth = 0.5
            borderPath.stroke()
            
            // Move to next position
            currentColumn += 1
            if currentColumn >= Layout.imagesPerRow {
                currentColumn = 0
                currentY += Layout.imageHeight + Layout.imageSpacing
            }
        }
        
        // If we ended mid-row, move to next row
        if currentColumn > 0 {
            currentY += Layout.imageHeight + Layout.imageSpacing
        }
        
        return currentY
    }
    
    private func drawFooter(at yPosition: CGFloat) {
        let footerText = "Báo cáo được tạo bởi report_lms • © 2026"
        let font = UIFont.systemFont(ofSize: Layout.captionFontSize)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.gray
        ]
        
        let textSize = footerText.size(withAttributes: attributes)
        let textRect = CGRect(
            x: Layout.margin + (Layout.contentWidth - textSize.width) / 2,
            y: yPosition,
            width: textSize.width,
            height: textSize.height
        )
        
        footerText.draw(in: textRect, withAttributes: attributes)
    }
    
    // MARK: - Helper Methods
    
    private func resizeImage(_ image: UIImage, to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
}
