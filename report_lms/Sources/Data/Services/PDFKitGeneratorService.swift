//
//  PDFKitGeneratorService.swift
//  report_lms
//
//  Qarma-style layout: cover page (title, info table, status banner, summary),
//  then one section per page with 4-column photo grid and per-page footer.
//

import Foundation
import UIKit
import OSLog

final class PDFKitGeneratorService: PDFGeneratorType {
    private let logger = Logger(subsystem: "com.reportlms.pdf", category: "pdfkit")

    // MARK: - Layout

    private enum Layout {
        static let pageWidth:    CGFloat = 595.2
        static let pageHeight:   CGFloat = 841.8
        static let margin:       CGFloat = 40
        static let contentWidth: CGFloat = pageWidth - 2 * margin

        // Footer sits at a fixed Y so content never overlaps it
        static let footerY:      CGFloat = pageHeight - 28
        static let contentMaxY:  CGFloat = pageHeight - 46   // stop drawing before footer

        // 4-column photo grid
        static let imagesPerRow: Int     = 4
        static let imageGap:     CGFloat = 8
        static let imageWidth:   CGFloat = (contentWidth - imageGap * CGFloat(imagesPerRow - 1)) / CGFloat(imagesPerRow)
        static let imageHeight:  CGFloat = imageWidth * 0.75   // 4:3

        // Table rows
        static let infoRowH:     CGFloat = 26
        static let tableRowH:    CGFloat = 24
        static let sectionSpacing: CGFloat = 22
        static let fieldSpacing:   CGFloat = 10
    }

    // MARK: - PDFGeneratorType

    func generatePDF(
        detail: Inspection,
        images: [String: [InspectionImage]],
        inspectorName: String,
        location: String,
        defectCounts: (critical: Int, major: Int, minor: Int),
        finalStatus: FinalReportStatus,
        summaryComments: String
    ) async throws -> Data {
        logger.log("Qarma PDF start: #\(detail.inspectionNumber)")

        let pageRect = CGRect(x: 0, y: 0, width: Layout.pageWidth, height: Layout.pageHeight)
        let format   = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "report_lms",
            kCGPDFContextTitle   as String: "Inspection Report \(detail.inspectionNumber)"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let df = DateFormatter()
        df.dateFormat = "MMM dd, yyyy"
        let dateStr   = df.string(from: detail.createdAt)
        let orderInfo = "Order: \(detail.inspectionNumber), Item: \(detail.productName)"
        var pageNum   = 0

        let data = renderer.pdfData { ctx in

            // ── PAGE 1: Cover ──────────────────────────────────────────
            ctx.beginPage()
            pageNum += 1
            drawFooter(orderInfo: orderInfo, dateStr: dateStr, pageNum: pageNum)

            var y = Layout.margin
            y = drawCoverPage(
                detail: detail,
                images: images,
                inspectorName: inspectorName,
                location: location,
                defectCounts: defectCounts,
                finalStatus: finalStatus,
                summaryComments: summaryComments,
                at: y
            )

            // ── PAGES 2+: Checkpoints ──────────────────────────────────
            let sorted = detail.sections.sorted { $0.order < $1.order }
            for (si, section) in sorted.enumerated() {
                let sNum = si + 1

                // Each top-level section always starts on a fresh page
                ctx.beginPage()
                pageNum += 1
                drawFooter(orderInfo: orderInfo, dateStr: dateStr, pageNum: pageNum)
                y = Layout.margin

                y = drawSectionHeader("\(sNum)   \(section.title)", at: y)
                y += 6

                for (fi, field) in section.fields.enumerated() {
                    let fNum       = fi + 1
                    let fieldImgs  = images[field.id] ?? []
                    let commentH   = fieldCommentHeight(field.comment)
                    let neededH: CGFloat = (fieldImgs.isEmpty ? 30 : Layout.imageHeight + 40) + commentH

                    if y + neededH > Layout.contentMaxY {
                        ctx.beginPage()
                        pageNum += 1
                        drawFooter(orderInfo: orderInfo, dateStr: dateStr, pageNum: pageNum)
                        y = Layout.margin
                    }

                    y = drawFieldHeading("\(sNum).\(fNum)   \(field.label)", at: y)

                    if !field.comment.isEmpty {
                        y = drawFieldComment(field.comment, at: y)
                    }

                    if !fieldImgs.isEmpty {
                        y = drawPhotoGrid(
                            images: fieldImgs, at: y,
                            ctx: ctx, pageNum: &pageNum,
                            orderInfo: orderInfo, dateStr: dateStr
                        )
                    }

                    y += Layout.fieldSpacing
                }

                y += Layout.sectionSpacing
            }
        }

        logger.log("Qarma PDF done: \(pageNum) pages, \(data.count) bytes")
        return data
    }

    // MARK: - Cover Page

    private func drawCoverPage(
        detail: Inspection,
        images: [String: [InspectionImage]],
        inspectorName: String,
        location: String,
        defectCounts: (critical: Int, major: Int, minor: Int),
        finalStatus: FinalReportStatus,
        summaryComments: String,
        at startY: CGFloat
    ) -> CGFloat {
        var y = startY

        // 1. Small grey report title
        let smallFont  = UIFont.systemFont(ofSize: 11)
        let greyAttrs: [NSAttributedString.Key: Any] = [.font: smallFont, .foregroundColor: UIColor(white: 0.5, alpha: 1)]
        "Inspection report, Final: \(detail.inspectionNumber)".draw(
            at: CGPoint(x: Layout.margin, y: y), withAttributes: greyAttrs
        )
        y += smallFont.lineHeight + 4

        // 2. Large bold product subtitle
        let bigFont   = UIFont.boldSystemFont(ofSize: 20)
        let bigAttrs: [NSAttributedString.Key: Any] = [.font: bigFont, .foregroundColor: UIColor.black]
        let subtitle  = "\(detail.productCode): \(detail.productName)"
        let subBounds = subtitle.boundingRect(
            with: CGSize(width: Layout.contentWidth, height: 80),
            options: .usesLineFragmentOrigin, attributes: bigAttrs, context: nil
        )
        subtitle.draw(
            with: CGRect(x: Layout.margin, y: y, width: Layout.contentWidth, height: subBounds.height),
            options: .usesLineFragmentOrigin, attributes: bigAttrs, context: nil
        )
        y += subBounds.height + 8

        // 3. Separator
        drawHLine(y: y)
        y += 10

        // 4. Info table
        let df = DateFormatter()
        df.dateFormat = "MMM dd, yyyy"
        let dateStr = df.string(from: detail.createdAt)

        y = drawInfoTable(rows: [
            ("Inspector",             inspectorName,
             "Inspection Date",       dateStr),
            ("Planned Sample/Insp.",  "\(detail.aqlInspectionQuantity)/\(detail.inspectedQuantity)",
             "Order Qty",             "\(detail.orderQuantity)"),
            ("Location",              location.isEmpty ? "N/A" : location,
             "Checklist Name",        "Final CheckList"),
            ("Planned Date",          dateStr,
             "Sampling Method",       "100% inspection"),
            ("Supplier Name",         detail.factoryName.isEmpty ? "N/A" : detail.factoryName,
             nil,                     nil),
        ], at: y)
        y += 8

        // 5. Inspector conclusion row
        y = drawConclusionRow(status: finalStatus, notes: summaryComments, at: y)
        y += 2

        // 6. Full-width status banner
        y = drawStatusBanner(status: finalStatus, at: y)
        y += 16

        // 7. SUMMARY heading
        let sumFont = UIFont.boldSystemFont(ofSize: 14)
        let sumAttrs: [NSAttributedString.Key: Any] = [.font: sumFont, .foregroundColor: UIColor.black]
        "SUMMARY".draw(at: CGPoint(x: Layout.margin, y: y), withAttributes: sumAttrs)
        y += sumFont.lineHeight + 8

        // 8. Checklist sections table
        y = drawChecklistTable(sections: detail.sections, images: images, at: y)
        y += 12

        // 9. Defect count table
        y = drawDefectTable(defectCounts: defectCounts, at: y)

        return y
    }

    // MARK: - Info Table

    /// rows: (leftLabel, leftValue, rightLabel?, rightValue?)
    /// When rightLabel is nil, leftValue spans the remaining width.
    private func drawInfoTable(
        rows: [(String, String, String?, String?)],
        at startY: CGFloat
    ) -> CGFloat {
        let border   = UIColor(white: 0.78, alpha: 1)
        let labelBg  = UIColor(white: 0.96, alpha: 1)
        let labelClr = UIColor(white: 0.35, alpha: 1)
        let labelFnt = UIFont.systemFont(ofSize: 10)
        let valueFnt = UIFont.systemFont(ofSize: 10)
        // 22% label + 28% value each side
        let lw = Layout.contentWidth * 0.22
        let vw = Layout.contentWidth * 0.28
        let rh = Layout.infoRowH
        var y  = startY

        for (ll, lv, rl, rv) in rows {
            drawCell(ll, rect: CGRect(x: Layout.margin, y: y, width: lw, height: rh),
                     bg: labelBg, fg: labelClr, font: labelFnt, border: border)

            if let rl, let rv {
                drawCell(lv, rect: CGRect(x: Layout.margin + lw, y: y, width: vw, height: rh),
                         bg: .white, fg: .black, font: valueFnt, border: border)
                drawCell(rl, rect: CGRect(x: Layout.margin + lw + vw, y: y, width: lw, height: rh),
                         bg: labelBg, fg: labelClr, font: labelFnt, border: border)
                drawCell(rv, rect: CGRect(x: Layout.margin + lw + vw + lw, y: y, width: vw, height: rh),
                         bg: .white, fg: .black, font: valueFnt, border: border)
            } else {
                drawCell(lv, rect: CGRect(x: Layout.margin + lw, y: y, width: Layout.contentWidth - lw, height: rh),
                         bg: .white, fg: .black, font: valueFnt, border: border)
            }
            y += rh
        }
        return y
    }

    // MARK: - Conclusion Row

    /// Row height grows to fit `notes` in full (no truncation) — returns `y + max(infoRowH, wrapped notes height)`.
    private func drawConclusionRow(status: FinalReportStatus, notes: String, at y: CGFloat) -> CGFloat {
        let labelFnt = UIFont.systemFont(ofSize: 10)
        let noteFnt  = UIFont.systemFont(ofSize: 9)
        let labelClr = UIColor(white: 0.30, alpha: 1)
        "Inspector Conclusion".draw(
            at: CGPoint(x: Layout.margin, y: y + 6),
            withAttributes: [.font: labelFnt, .foregroundColor: labelClr]
        )

        let badgeX = Layout.margin + 130
        let badgeW = drawStatusBadge(status: status, at: CGPoint(x: badgeX, y: y + 4))

        var rowH = Layout.infoRowH
        if !notes.isEmpty {
            let notesX = badgeX + badgeW + 10
            let notesW = Layout.margin + Layout.contentWidth - notesX
            let noteAttrs: [NSAttributedString.Key: Any] = [.font: noteFnt, .foregroundColor: labelClr]
            let notesBounds = notes.boundingRect(
                with: CGSize(width: notesW, height: 400),
                options: .usesLineFragmentOrigin, attributes: noteAttrs, context: nil
            )
            notes.draw(
                with: CGRect(x: notesX, y: y + 4, width: notesW, height: notesBounds.height),
                options: .usesLineFragmentOrigin,
                attributes: noteAttrs,
                context: nil
            )
            rowH = max(rowH, notesBounds.height + 8)
        }
        return y + rowH
    }

    // MARK: - Status Badge

    @discardableResult
    private func drawStatusBadge(status: FinalReportStatus, at point: CGPoint) -> CGFloat {
        let text = status.displayName.uppercased()
        let font = UIFont.boldSystemFont(ofSize: 9)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
        let tSz  = text.size(withAttributes: attrs)
        let hPad: CGFloat = 8, vPad: CGFloat = 3
        let bW = tSz.width + hPad * 2
        let bH = tSz.height + vPad * 2

        statusColor(status).setFill()
        UIBezierPath(roundedRect: CGRect(x: point.x, y: point.y, width: bW, height: bH), cornerRadius: 2).fill()
        text.draw(at: CGPoint(x: point.x + hPad, y: point.y + vPad), withAttributes: attrs)
        return bW
    }

    // MARK: - Status Banner

    private func drawStatusBanner(status: FinalReportStatus, at y: CGFloat) -> CGFloat {
        let h: CGFloat = 26
        statusColor(status).setFill()
        UIBezierPath(rect: CGRect(x: Layout.margin, y: y, width: Layout.contentWidth, height: h)).fill()

        let font  = UIFont.boldSystemFont(ofSize: 10)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
        let labelFnt = UIFont.systemFont(ofSize: 10)
        "Status:".draw(
            at: CGPoint(x: Layout.margin + 10, y: y + 6),
            withAttributes: [.font: labelFnt, .foregroundColor: UIColor.white]
        )
        status.displayName.uppercased().draw(
            at: CGPoint(x: Layout.margin + 64, y: y + 6),
            withAttributes: attrs
        )
        return y + h
    }

    // MARK: - Checklist Summary Table

    private func drawChecklistTable(
        sections: [InspectionSection],
        images: [String: [InspectionImage]],
        at startY: CGFloat
    ) -> CGFloat {
        let border    = UIColor(white: 0.82, alpha: 1)
        let headerBg  = UIColor(white: 0.95, alpha: 1)
        let boldFnt   = UIFont.boldSystemFont(ofSize: 10)
        let regFnt    = UIFont.systemFont(ofSize: 10)
        let rh        = Layout.tableRowH
        let nameW     = Layout.contentWidth * 0.82
        let statusW   = Layout.contentWidth - nameW
        var y         = startY

        // Header
        drawCell("Checklist Section",
                 rect: CGRect(x: Layout.margin, y: y, width: nameW, height: rh),
                 bg: headerBg, fg: .black, font: boldFnt, border: border)
        drawCell("Status",
                 rect: CGRect(x: Layout.margin + nameW, y: y, width: statusW, height: rh),
                 bg: headerBg, fg: .black, font: boldFnt, border: border)
        y += rh

        for (i, section) in sections.sorted(by: { $0.order < $1.order }).enumerated() {
            let total = section.fields.count
            let completed = section.fields.filter { !(images[$0.id]?.isEmpty ?? true) }.count
            let progress: CGFloat = total > 0 ? CGFloat(completed) / CGFloat(total) : 0
            let rowBg = i % 2 == 0 ? UIColor.white : UIColor(white: 0.985, alpha: 1)

            drawCell("\(i + 1)   \(section.title)",
                     rect: CGRect(x: Layout.margin, y: y, width: nameW, height: rh),
                     bg: rowBg, fg: .black, font: regFnt, border: border)

            // Status cell: background + border + progress bar — mirrors the Cloud Function's
            // drawChecklistTable (functions/src/index.ts) so local and emailed PDFs show the
            // same completion stat for a section, not just the same colors/spacing.
            let cellRect = CGRect(x: Layout.margin + nameW, y: y, width: statusW, height: rh)
            rowBg.setFill()
            UIBezierPath(rect: cellRect).fill()
            border.setStroke()
            let cellBorder = UIBezierPath(rect: cellRect)
            cellBorder.lineWidth = 0.5
            cellBorder.stroke()

            let barW: CGFloat = 55
            let barH: CGFloat = 5
            let barX = cellRect.midX - barW / 2
            let barY = cellRect.midY - barH / 2
            UIColor(white: 0.88, alpha: 1).setFill()
            UIBezierPath(rect: CGRect(x: barX, y: barY, width: barW, height: barH)).fill()
            if progress > 0 {
                checklistProgressColor(progress).setFill()
                UIBezierPath(rect: CGRect(x: barX, y: barY, width: barW * progress, height: barH)).fill()
            }

            y += rh
        }
        return y
    }

    /// Same thresholds as the Cloud Function's `progressColor` in `functions/src/index.ts`.
    private func checklistProgressColor(_ progress: CGFloat) -> UIColor {
        if progress <= 0 { return UIColor(white: 0.6196, alpha: 1) }          // #9e9e9e
        if progress < 0.5 { return UIColor(red: 1.0, green: 0.5961, blue: 0.0, alpha: 1) }      // #ff9800
        if progress < 1.0 { return UIColor(red: 0.1294, green: 0.5882, blue: 0.9529, alpha: 1) } // #2196f3
        return UIColor(red: 0.20, green: 0.6314, blue: 0.2902, alpha: 1)      // #33a14a
    }

    // MARK: - Defect Count Table

    private func drawDefectTable(
        defectCounts: (critical: Int, major: Int, minor: Int),
        at startY: CGFloat
    ) -> CGFloat {
        let border   = UIColor(white: 0.82, alpha: 1)
        let headerBg = UIColor(white: 0.95, alpha: 1)
        let bold     = UIFont.boldSystemFont(ofSize: 10)
        let rh       = Layout.tableRowH
        let descW    = Layout.contentWidth * 0.52
        let colW     = (Layout.contentWidth - descW) / 3
        var y        = startY

        let critClr  = UIColor(red: 0.78, green: 0.15, blue: 0.15, alpha: 1)
        let majClr   = UIColor(red: 0.90, green: 0.55, blue: 0.05, alpha: 1)
        let minClr   = UIColor(red: 0.15, green: 0.45, blue: 0.80, alpha: 1)

        // Header row
        drawCell("", rect: CGRect(x: Layout.margin, y: y, width: descW, height: rh),
                 bg: headerBg, fg: .black, font: bold, border: border)
        drawCell("CRITICAL", rect: CGRect(x: Layout.margin + descW, y: y, width: colW, height: rh),
                 bg: headerBg, fg: critClr, font: bold, border: border)
        drawCell("MAJOR",    rect: CGRect(x: Layout.margin + descW + colW, y: y, width: colW, height: rh),
                 bg: headerBg, fg: majClr, font: bold, border: border)
        drawCell("MINOR",    rect: CGRect(x: Layout.margin + descW + colW * 2, y: y, width: colW, height: rh),
                 bg: headerBg, fg: minClr, font: bold, border: border)
        y += rh

        // TOTAL row
        let cVal = defectCounts.critical
        let mVal = defectCounts.major
        let nVal = defectCounts.minor
        drawCell("TOTAL", rect: CGRect(x: Layout.margin, y: y, width: descW, height: rh),
                 bg: .white, fg: .black, font: bold, border: border)
        drawCell("\(cVal)", rect: CGRect(x: Layout.margin + descW, y: y, width: colW, height: rh),
                 bg: .white, fg: cVal > 0 ? critClr : .black, font: bold, border: border)
        drawCell("\(mVal)", rect: CGRect(x: Layout.margin + descW + colW, y: y, width: colW, height: rh),
                 bg: .white, fg: mVal > 0 ? majClr : .black, font: bold, border: border)
        drawCell("\(nVal)", rect: CGRect(x: Layout.margin + descW + colW * 2, y: y, width: colW, height: rh),
                 bg: .white, fg: nVal > 0 ? minClr : .black, font: bold, border: border)
        y += rh

        return y
    }

    // MARK: - Section & Field Headers

    private func drawSectionHeader(_ title: String, at y: CGFloat) -> CGFloat {
        let font  = UIFont.boldSystemFont(ofSize: 14)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
        let bounds = title.boundingRect(
            with: CGSize(width: Layout.contentWidth, height: 40),
            options: .usesLineFragmentOrigin, attributes: attrs, context: nil
        )
        title.draw(
            with: CGRect(x: Layout.margin, y: y, width: Layout.contentWidth, height: bounds.height),
            options: .usesLineFragmentOrigin, attributes: attrs, context: nil
        )
        let lineY = y + bounds.height + 3
        let path  = UIBezierPath()
        path.move(to: CGPoint(x: Layout.margin, y: lineY))
        path.addLine(to: CGPoint(x: Layout.margin + Layout.contentWidth, y: lineY))
        UIColor(red: 0.20, green: 0.40, blue: 0.85, alpha: 1).setStroke()
        path.lineWidth = 1.5
        path.stroke()
        return lineY + 6
    }

    private func drawFieldHeading(_ text: String, at y: CGFloat) -> CGFloat {
        let font  = UIFont.systemFont(ofSize: 11)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(white: 0.25, alpha: 1)]
        text.draw(at: CGPoint(x: Layout.margin, y: y), withAttributes: attrs)
        return y + font.lineHeight + 4
    }

    // MARK: - Field Comment

    private func fieldCommentAttrs() -> [NSAttributedString.Key: Any] {
        [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor(white: 0.30, alpha: 1)]
    }

    /// Height a field's "Comment: <text>" line will occupy, or 0 when there is no comment.
    private func fieldCommentHeight(_ comment: String) -> CGFloat {
        guard !comment.isEmpty else { return 0 }
        let bounds = "Comment: \(comment)".boundingRect(
            with: CGSize(width: Layout.contentWidth, height: 400),
            options: .usesLineFragmentOrigin, attributes: fieldCommentAttrs(), context: nil
        )
        return bounds.height + 6
    }

    /// Draws a field-level remark ("Comment: <text>") above that field's photo grid, wrapped
    /// to full width with no truncation.
    private func drawFieldComment(_ comment: String, at startY: CGFloat) -> CGFloat {
        let text   = "Comment: \(comment)"
        let attrs  = fieldCommentAttrs()
        let bounds = text.boundingRect(
            with: CGSize(width: Layout.contentWidth, height: 400),
            options: .usesLineFragmentOrigin, attributes: attrs, context: nil
        )
        text.draw(
            with: CGRect(x: Layout.margin, y: startY, width: Layout.contentWidth, height: bounds.height),
            options: .usesLineFragmentOrigin, attributes: attrs, context: nil
        )
        return startY + bounds.height + 6
    }

    // MARK: - 4-Column Photo Grid

    private func drawPhotoGrid(
        images: [InspectionImage],
        at startY: CGFloat,
        ctx: UIGraphicsPDFRendererContext,
        pageNum: inout Int,
        orderInfo: String,
        dateStr: String
    ) -> CGFloat {
        var y = startY

        let captionFont    = UIFont.systemFont(ofSize: 11)
        let captionColor   = UIColor(white: 0.35, alpha: 1)
        let captionTopPad: CGFloat = 4
        // Reserve height for up to 2 wrapped lines of caption text
        let captionMaxH: CGFloat   = ceil(captionFont.lineHeight * 2) + 2

        let measurementFont  = UIFont.systemFont(ofSize: 11)
        let measurementColor = UIColor(white: 0.35, alpha: 1)
        let measurementTopPad: CGFloat = 2
        let measurementMaxH: CGFloat   = ceil(measurementFont.lineHeight)

        // Process images row-by-row so captions can be drawn under each row
        // and page-break decisions include caption height when needed.
        let rows = stride(from: 0, to: images.count, by: Layout.imagesPerRow).map {
            Array(images[$0..<min($0 + Layout.imagesPerRow, images.count)])
        }

        for row in rows {
            let hasCaption = row.contains { !$0.description.isEmpty }
            let hasMeasurement = row.contains { $0.measurementMMValue != nil }
            let rowH = Layout.imageHeight
                + (hasCaption ? captionTopPad + captionMaxH : 0)
                + (hasMeasurement ? measurementTopPad + measurementMaxH : 0)

            if y + rowH > Layout.contentMaxY {
                ctx.beginPage()
                pageNum += 1
                drawFooter(orderInfo: orderInfo, dateStr: dateStr, pageNum: pageNum)
                y = Layout.margin
            }

            // Draw images
            for (col, img) in row.enumerated() {
                let x       = Layout.margin + CGFloat(col) * (Layout.imageWidth + Layout.imageGap)
                let imgRect = CGRect(x: x, y: y, width: Layout.imageWidth, height: Layout.imageHeight)
                let inset   = imgRect.insetBy(dx: 1, dy: 1)

                ctx.cgContext.saveGState()
                UIBezierPath(roundedRect: inset, cornerRadius: 4).addClip()
                drawAspectFit(img.image, in: inset)
                ctx.cgContext.restoreGState()

                UIColor(white: 0.75, alpha: 1).setStroke()
                let border = UIBezierPath(roundedRect: inset, cornerRadius: 4)
                border.lineWidth = 0.5
                border.stroke()
            }

            // Draw captions below the row (only for images with non-empty description)
            if hasCaption {
                let captionY = y + Layout.imageHeight + captionTopPad
                for (col, img) in row.enumerated() {
                    guard !img.description.isEmpty else { continue }
                    let x = Layout.margin + CGFloat(col) * (Layout.imageWidth + Layout.imageGap)
                    img.description.draw(
                        with: CGRect(x: x, y: captionY, width: Layout.imageWidth, height: captionMaxH),
                        options: .usesLineFragmentOrigin,
                        attributes: [.font: captionFont, .foregroundColor: captionColor],
                        context: nil
                    )
                }
            }

            // Draw measurement (mm/inch) on its own line below the caption
            if hasMeasurement {
                let measurementY = y + Layout.imageHeight
                    + (hasCaption ? captionTopPad + captionMaxH : 0)
                    + measurementTopPad
                for (col, img) in row.enumerated() {
                    guard let mm = img.measurementMMValue else { continue }
                    let inchText = String(format: "%.2f", mm / 25.4)
                    let x = Layout.margin + CGFloat(col) * (Layout.imageWidth + Layout.imageGap)
                    "\(mm) mm (\(inchText) inch)".draw(
                        with: CGRect(x: x, y: measurementY, width: Layout.imageWidth, height: measurementMaxH),
                        options: .usesLineFragmentOrigin,
                        attributes: [.font: measurementFont, .foregroundColor: measurementColor],
                        context: nil
                    )
                }
            }

            y += rowH + Layout.imageGap
        }

        return y
    }

    // MARK: - Per-Page Footer

    private func drawFooter(orderInfo: String, dateStr: String, pageNum: Int) {
        let font  = UIFont.systemFont(ofSize: 8)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor(white: 0.5, alpha: 1)]

        // Separator line
        let lineY = Layout.footerY - 5
        let sep   = UIBezierPath()
        sep.move(to: CGPoint(x: Layout.margin, y: lineY))
        sep.addLine(to: CGPoint(x: Layout.margin + Layout.contentWidth, y: lineY))
        UIColor(white: 0.82, alpha: 1).setStroke()
        sep.lineWidth = 0.5
        sep.stroke()

        // Left: creator credit
        "Report created with report_lms.".draw(
            at: CGPoint(x: Layout.margin, y: Layout.footerY),
            withAttributes: attrs
        )

        // Right: order info + date + page
        let rightText = "\(orderInfo)   \(dateStr), page: \(pageNum)"
        let rightW    = rightText.size(withAttributes: attrs).width
        rightText.draw(
            at: CGPoint(x: Layout.margin + Layout.contentWidth - rightW, y: Layout.footerY),
            withAttributes: attrs
        )
    }

    // MARK: - Generic Cell Drawer

    private func drawCell(
        _ text: String,
        rect: CGRect,
        bg: UIColor,
        fg: UIColor,
        font: UIFont,
        border: UIColor
    ) {
        bg.setFill()
        UIBezierPath(rect: rect).fill()

        border.setStroke()
        let bp = UIBezierPath(rect: rect)
        bp.lineWidth = 0.5
        bp.stroke()

        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fg]
        let pad: CGFloat = 5
        text.draw(
            with: rect.insetBy(dx: pad, dy: pad * 0.6),
            options: .usesLineFragmentOrigin,
            attributes: attrs,
            context: nil
        )
    }

    // MARK: - Helpers

    private func drawHLine(y: CGFloat) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: Layout.margin, y: y))
        path.addLine(to: CGPoint(x: Layout.margin + Layout.contentWidth, y: y))
        UIColor(white: 0.75, alpha: 1).setStroke()
        path.lineWidth = 0.75
        path.stroke()
    }

    private func statusColor(_ status: FinalReportStatus) -> UIColor {
        switch status {
        case .accepted: return UIColor(red: 0.20, green: 0.63, blue: 0.29, alpha: 1)
        case .rejected: return UIColor(red: 0.78, green: 0.15, blue: 0.15, alpha: 1)
        case .pending:  return UIColor(red: 0.90, green: 0.60, blue: 0.05, alpha: 1)
        }
    }

    /// Draws `image` inside `rect`, scaled to fit while preserving aspect ratio and centered
    /// (mirrors SwiftUI's `.aspectRatio(contentMode: .fit)`) — unlike a plain `image.draw(in:)`
    /// into `rect`, which stretches the image to the exact rect size and distorts it whenever
    /// the source aspect ratio doesn't match the target box.
    private func drawAspectFit(_ image: UIImage, in rect: CGRect) {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }
        let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: rect.minX + (rect.width - fittedSize.width) / 2,
            y: rect.minY + (rect.height - fittedSize.height) / 2
        )
        image.draw(in: CGRect(origin: origin, size: fittedSize))
    }
}
