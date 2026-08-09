# PDF Report — Builder Pattern Quick Reference

## Current Implementation

```swift
let request = try PDFReportRequestBuilder.withDefaults()
    .with(inspection: detail)
    .with(images: capturedPhotos)
    .with(location: location)
    .with(finalStatus: selectedStatus)       // inspector conclusion
    .with(summaryComments: summaryComments)  // optional notes
    .build()

let data = try await generatePDFUseCase.execute(request: request)
```

---

## Builder Fields

| Method | Type | Required | Default |
|--------|------|----------|---------|
| `.with(inspection:)` | `Inspection` | ✅ | — |
| `.with(images:)` | `[String: [InspectionImage]]` | — | `[:]` |
| `.with(location:)` | `String` | ✅ | — |
| `.with(inspectorName:)` | `String` | ✅ | set by `withDefaults()` |
| `.with(defectCounts:)` | `(critical:major:minor:)` | — | `(0,0,0)` |
| `.with(finalStatus:)` | `FinalReportStatus` | — | `.pending` |
| `.with(summaryComments:)` | `String` | — | `""` |

`PDFReportRequestBuilder.withDefaults()` pre-fills `inspectorName` from `KeychainManager`.

---

## PDF Layout (Qarma Style)

Both `generateAndPreviewPDF()` (local) and `sendReportViaQueue()` (Firebase) produce the same output.

### Page 1 — Cover
- Small grey title + bold product subtitle
- Bordered info table (4 cols: 22% label / 28% value repeated)
- Inspector Conclusion row with coloured badge + summary notes — row height now grows to fit `summaryComments` in full (added 2026-08-09; previously a fixed-height/single-line rect that clipped long notes). `drawConclusionRow` measures wrapped text height (`boundingRect` on iOS / `doc.heightOfString` on the Cloud Function) and returns `y + max(infoRowH, notesHeight + padding)` instead of a constant. This is the **only** place `summaryComments` renders on the cover page — an earlier iteration also added a separate "Summary Comments" section below the defect table, which was removed the same day to avoid showing the same text twice.
- Full-width status banner (green / orange / red)
- SUMMARY section: checklist table + defect count table

### Pages 2+ — Per Section
- Sections **with images** start on a fresh page; sections **without images** continue on the current page (new page only if `y + 60 > CONTENT_MAX_Y`)
- Section header (bold 14pt + blue underline)
- Fields numbered `S.F` (e.g. `1.2 Field Label`)
- **Field comment** (added 2026-08-09): per-field `InspectionField.comment`, when non-empty, renders as `"Comment: <text>"` (iOS, hardcoded English) / `t(lang, "fieldComment")` (Cloud Function — `"Nhận xét:"` vi / `"Comment:"` en) directly above that field's photo grid. Full text wraps, no truncation. Its wrapped height is included in the field's page-break `neededH` calculation so it can't get orphaned across a page boundary independently of its photo grid. Source: `InspectionValidationView`'s "Nhận xét" `TextEditor` — see `InspectionValidationView.md#comments-persistence` for the full save/load chain (this was a dormant UI field that never reached Firestore until this fix).
- 4-column photo grid (≈122×92 pt per image, 4:3 ratio) — **aspect-fit** (preserves source aspect ratio, centered, letterboxed if not 4:3). Previously stretched to fill the cell and distorted non-4:3 photos — fixed on both the Cloud Function (`doc.image(..., { fit: [w, h], align: "center", valign: "center" })`) and iOS (`PDFKitGeneratorService.drawAspectFit`, replacing the old stretch-only `resizeImage`)
- Footer on every page: separator + "Report created with report_lms." + "Order:… page: N"

---

## Error Handling

```swift
do {
    let request = try PDFReportRequestBuilder.withDefaults()
        .with(inspection: detail)
        .with(images: capturedPhotos)
        .with(location: location)
        .with(finalStatus: selectedStatus)
        .with(summaryComments: summaryComments)
        .build()                              // ← validates here

    let data = try await generatePDFUseCase.execute(request: request)
} catch let error as PDFReportBuilderError {
    // Missing required field
} catch {
    // PDF generation failed
}
```

---

## Common Pitfalls

### Forgetting `.build()`
```swift
// ❌ Returns the builder, not a request
let request = PDFReportRequestBuilder().with(inspection: detail)

// ✅ Correct
let request = try PDFReportRequestBuilder().with(inspection: detail).build()
```

### Reusing builder without reset
```swift
// ❌ State leaks — req2 still has detail1
let req1 = try builder.with(inspection: detail1).build()
let req2 = try builder.with(inspection: detail2).build()

// ✅ Correct
let req1 = try builder.with(inspection: detail1).build()
builder.reset()
let req2 = try builder.with(inspection: detail2).build()
```

---

## Firebase Queue Delivery

`sendReportViaQueue()` passes `finalStatus` and `summaryComments` to the Firestore task document.  
The Cloud Function reads them and renders the same Qarma cover page in the server-side PDF.

```swift
// FinalReportViewModel.sendReportViaQueue()
let taskId = try await queueDeliveryUseCase.execute(
    inspection: inspection,
    recipients: allRecipients,
    location: location,
    finalStatus: selectedStatus,      // → Firestore "finalStatus": "accepted"
    summaryComments: summaryComments  // → Firestore "summaryComments": "..."
)
```

`FinalReportStatus.serverKey` converts Vietnamese raw values to ASCII keys:

| Case | rawValue | serverKey |
|------|----------|-----------|
| `.accepted` | "Chấp nhận" | `"accepted"` |
| `.pending` | "Đang chờ xử lý" | `"pending"` |
| `.rejected` | "Từ chối" | `"rejected"` |

---

## Related Files

| File | Role |
|------|------|
| `PDFReportRequest.swift` | Request model (Domain/Entities) |
| `PDFReportRequestBuilder.swift` | Builder (Domain/Entities) — `.build()` only now, `buildWithDefaults()` removed (unused) |
| `PDFKitGeneratorService.swift` | iOS PDF renderer — Qarma layout, aspect-fit photo grid, full-text-wrapping Inspector Conclusion row, per-field Comment line (Data/Services) |
| `GenerateHTMLPDFReportUseCase.swift` | Use case wiring builder → service (Domain/UseCases) — `execute(request:)` only now, direct-params overload removed (unused) |
| `PDFGeneratorType.swift` | Protocol (Domain/Repositories) — `PDFGenerationError` removed (no throw sites left) |
| `FinalReportViewModel.swift` | Queue delivery (`sendReportViaQueue`) + legacy mail-composer fallback (`generateAndSendPDF`, only reachable if `FeatureFlags.useFirebaseReportDelivery == false`). `generateAndPreviewPDF()`/`isShowingPDFPreview` removed — dead since the "Xem PDF" preview button was removed from the UI |
| `functions/src/index.ts` | Cloud Function — same Qarma layout in Node.js/pdfkit, aspect-fit photo grid, trace-CC/Reply-To to `requestedBy` |

---

*Last updated: 2026-08-09 (v2, same day) — feat/login branch — reverted the separate cover-page "Summary Comments" section (was duplicating `summaryComments` alongside the existing Inspector Conclusion notes) and instead fixed the original notes-next-to-badge text to wrap and grow to fit the full comment, no truncation, no duplication; added per-field Comment line above each field's photo grid, sourced from `InspectionValidationView`'s previously-dormant "Nhận xét" input (fixed its Firestore persistence — see `InspectionValidationView.md#comments-persistence`); all changes mirrored on iOS and the Cloud Function; Cloud Function deployed to `reportlms-7e6b6` (`processReportQueue`, asia-southeast1).*

*Previously updated: 2026-07-04 — blank page fix (PDFDocument margins→0); smart section page-break; "Xem PDF" button removed from UI; removed dead code left behind by that removal (`generateAndPreviewPDF`, `buildWithDefaults`, direct-params `execute()` overload, `PDFGenerationError`); trace-CC + Reply-To to `requestedBy`; photo grid switched from stretch to aspect-fit.*
