# Final Report — Feature Document

> **Jira:** — | **Branch:** `feat/login` | **Generated:** 2026-07-08

> Jira/Confluence not fetched — no ticket key found in the current branch name (`feat/login`) and no `JIRA`/`CONFLUENCE` params were provided.
> ℹ️ This module is SwiftUI + `@Published`/async-await MVVM, not RxSwift/MVVM-C, so "Architecture Overview" below is adapted from the standard template accordingly.
> ℹ️ Two related docs already exist alongside this one in the same folder: [`FIREBASE_REPORT_DELIVERY.md`](FIREBASE_REPORT_DELIVERY.md) (server delivery pipeline) and [`PDF_REFACTORING_QUICK_REFERENCE.md`](PDF_REFACTORING_QUICK_REFERENCE.md) (PDF builder pattern). This document covers the `FinalReportView`/`FinalReportViewModel` screen itself; see those two for deep dives into PDF rendering and Cloud Function delivery.

---

## PRD Summary

> What the feature does and why it exists.

- **Goal:** Let an inspector close out a completed inspection — review quantities, set a final status and conclusion notes, pick recipients, and send the inspection report as a PDF — from one screen.
- **User story:** As an inspector, I want to record my final conclusion on an inspection and send the report to selected recipients so that stakeholders receive the outcome and the inspection is marked complete.
- **Acceptance criteria:**
  - Not available — add manually (no Jira ticket linked to this branch)

---

## Business Rules

> Key business constraints and logic, verified against [`FinalReportViewModel.swift`](FinalReportViewModel.swift) and its dependencies.

| Rule | Description |
|------|-------------|
| Delivery routing | `sendReport()` sends via the Firebase Firestore queue when `FeatureFlags.useFirebaseReportDelivery == true`, otherwise falls back to the legacy on-device Mail composer path (`generateAndSendPDF()`) ([`FinalReportViewModel.swift:186-192`](FinalReportViewModel.swift#L186-L192)). |
| Feature flag currently hardcoded | `FeatureFlags.useFirebaseReportDelivery` is hardcoded `true` with the code comment `// TODO: revert before commit` ([`FeatureFlags.swift:12`](../../../../Common/Helpers/FeatureFlags.swift#L12)) — the legacy Mail composer branch is not currently reachable in this build. |
| Default recipient email is hardcoded | `recipientEmail` is pre-filled with the literal string `"freelancerios0502@gmail.com"` for every session, not derived from any user/session state ([`FinalReportViewModel.swift:84`](FinalReportViewModel.swift#L84)). |
| Recipients picker is mock data | `availableRecipients` returns `FinalReportRecipient.mockRecipients` — a hardcoded list of 8 fictitious names/emails ([`FinalReportViewModel.swift:61-63`](FinalReportViewModel.swift#L61-L63), [`FinalReportRecipient.swift:22-31`](../../../../Domain/Entities/FinalReportRecipient.swift#L22-L31)); it is not backed by a contacts service or backend. |
| Recipient list assembly | The final recipient list = `selectedRecipients` (from the mock picker) + the trimmed `recipientEmail` text field value, if non-empty ([`FinalReportViewModel.swift:206-210`](FinalReportViewModel.swift#L206-L210)). |
| No-recipient guard | `QueueReportDeliveryUseCase.execute` throws `QueueDeliveryError.noRecipients` if, after filtering empty strings, no recipient has an email ([`QueueReportDeliveryUseCase.swift:38-43`](../../../../Domain/UseCases/QueueReportDeliveryUseCase.swift#L38-L43)). |
| Send deferred during active uploads | If `inspectionDetailVM.activeUploadCount > 0` when the user taps "Send Email", the tap opens the Upload Status sheet and sets `pendingEmailSend = true` instead of sending immediately; the actual send fires once `activeUploadCount` reaches 0 via `.onChange` ([`FinalReportView.swift:336-361`](FinalReportView.swift#L336-L361)). |
| Fresh-read before marking complete | `markInspectionCompleted()` deliberately re-fetches the inspection from `storageService` instead of using the `inspection` property (a snapshot from when the view opened) — the code comment explains this avoids overwriting `imageURLs` back to `[]` in Firestore, since uploads may have completed after the view opened ([`FinalReportViewModel.swift:243-246`](FinalReportViewModel.swift#L243-L246)). |
| Status → server key mapping | `FinalReportStatus` raw values are Vietnamese display strings ("Chấp nhận"/"Đang chờ xử lý"/"Từ chối"); `serverKey` maps them to the ASCII keys ("accepted"/"pending"/"rejected") the Cloud Function expects ([`FinalReportStatus.swift:10-37`](../../../../Domain/Entities/FinalReportStatus.swift#L10-L37)). |
| Language passthrough | `language` sent in the queue payload is `LocalizationManager.shared.currentLanguage.rawValue`, which is `"vi"`/`"en"` ([`AppLanguage`, `LocalizationManager.swift:13-15`](../../../../Common/Helpers/LocalizationManager.swift#L13-L15)) — matches the `Lang` type expected by the Cloud Function's `TRANSLATIONS` table. |
| Only remote-skip on photo save | `allPhotos` (used by "Save Photos") excludes images already on Firebase (`isRemote == true`), saving only locally captured photos to the device library ([`FinalReportViewModel.swift:65-68`](FinalReportViewModel.swift#L65-L68)). |

---

## Architecture Overview

> SwiftUI view + `@MainActor ObservableObject` view model, async/await for I/O — no RxSwift/Combine relays.

### Key Components

| Layer | File | Role |
|-------|------|------|
| Presentation | [`FinalReportView.swift`](FinalReportView.swift) | SwiftUI screen: quantities, status picker, location, summary notes, recipients, email field, send/save actions |
| Presentation (state) | [`FinalReportViewModel.swift`](FinalReportViewModel.swift) | `@MainActor` `ObservableObject`; owns all `@Published` UI state, routes the send flow, drives PDF generation and photo saving |
| Domain | [`FinalReportStatus.swift`](../../../../Domain/Entities/FinalReportStatus.swift) | Status enum (Vietnamese display name + ASCII `serverKey`) |
| Domain | [`FinalReportRecipient.swift`](../../../../Domain/Entities/FinalReportRecipient.swift) | Recipient model + mock data source |
| Domain | [`QueueReportDeliveryUseCase.swift`](../../../../Domain/UseCases/QueueReportDeliveryUseCase.swift) | Validates recipients, builds the Firestore task payload, enqueues, exposes `statusStream` |
| Domain | [`GenerateHTMLPDFReportUseCase.swift`](../../../../Domain/UseCases/GenerateHTMLPDFReportUseCase.swift) | Legacy path only: builds the PDF locally for the Mail composer |
| Domain | [`PDFReportRequestBuilder.swift`](../../../../Domain/Entities/PDFReportRequestBuilder.swift), [`PDFReportRequest.swift`](../../../../Domain/Entities/PDFReportRequest.swift) | Builder-pattern request object feeding the legacy local PDF path |
| Domain | [`PDFGeneratorType.swift`](../../../../Domain/Repositories/PDFGeneratorType.swift) | Protocol implemented by the local PDF renderer |
| Data | [`ReportDeliveryQueueService.swift`](../../../../Data/Services/ReportDeliveryQueueService.swift) | Firestore reads/writes for `report_delivery_queue` |
| Data | [`PDFKitGeneratorService.swift`](../../../../Data/Services/PDFKitGeneratorService.swift) | Local PDFKit renderer, used only by the legacy Mail composer path |
| Config | [`FeatureFlags.swift`](../../../../Common/Helpers/FeatureFlags.swift) | Switches between Firebase-queue delivery and the legacy Mail composer |

### Data Flow

```
User taps "Send Email" (FinalReportView.actionButtonsSection)
  → FinalReportViewModel.sendReport()
    ├─ if FeatureFlags.useFirebaseReportDelivery (currently hardcoded true):
    │    → sendReportViaQueue()
    │      → QueueReportDeliveryUseCase.execute(inspection:recipients:location:finalStatus:summaryComments:)
    │        → ReportDeliveryQueueService.enqueue(_:) → Firestore doc created (report_delivery_queue/{taskId})
    │      → showEmailQueuedAlert = true
    │      → markInspectionCompleted() → storageService.updateInspection(status: .completed)
    │      → for await status in queueDeliveryUseCase.statusStream(taskId:)
    │          ├─ .sent   → showEmailSuccessAlert = true
    │          └─ .failed → errorAlertMessage set, showErrorAlert = true
    └─ else (not currently reachable — flag hardcoded true):
         → generateAndSendPDF()
           → PDFReportRequestBuilder.withDefaults()...build() → GenerateHTMLPDFReportUseCase.execute(request:)
           → pdfData set, isShowingMailComposer = true → MailComposerView sheet
           → onComplete(.sent) → handleEmailSent() → markInspectionCompleted()
```

---

## Key Files & Symbols

> Files under `FinalReport/` changed on this branch (git diff `main...HEAD`), plus verified cross-references.

### Presentation
- [`FinalReportView.swift`](FinalReportView.swift) — SwiftUI screen (quantities/status/location/summary/notification/email sections, action buttons, photo save, sheets/alerts)
- [`FinalReportViewModel.swift`](FinalReportViewModel.swift) — `@Published` state, send/queue orchestration, photo library saving

### Domain (referenced, not in this diff)
- [`FinalReportStatus.swift`](../../../../Domain/Entities/FinalReportStatus.swift) — status enum + `serverKey`
- [`FinalReportRecipient.swift`](../../../../Domain/Entities/FinalReportRecipient.swift) — recipient model + `mockRecipients`
- [`QueueReportDeliveryUseCase.swift`](../../../../Domain/UseCases/QueueReportDeliveryUseCase.swift) — Firebase queue delivery use case
- [`GenerateHTMLPDFReportUseCase.swift`](../../../../Domain/UseCases/GenerateHTMLPDFReportUseCase.swift) — legacy local PDF use case
- [`PDFReportRequestBuilder.swift`](../../../../Domain/Entities/PDFReportRequestBuilder.swift) / [`PDFReportRequest.swift`](../../../../Domain/Entities/PDFReportRequest.swift) — legacy request builder

### Data (referenced, not in this diff)
- [`ReportDeliveryQueueService.swift`](../../../../Data/Services/ReportDeliveryQueueService.swift) — Firestore queue read/write
- [`PDFKitGeneratorService.swift`](../../../../Data/Services/PDFKitGeneratorService.swift) — local PDF renderer (legacy path)

### Shared UI components used (verified to exist, not new in this diff)
- `LMSSectionContainer`, `LMSInfoRow`, `LMSButton`, `LMSLabel`, `LMSLoadingOverlay`, `SuccessConfirmationView`, `MailComposerView`, `UploadStatusBottomSheet`, `LMSColor`

### Pre-existing docs in this folder (not generated by this run)
- [`FIREBASE_REPORT_DELIVERY.md`](FIREBASE_REPORT_DELIVERY.md) — full server delivery pipeline (Firestore → Cloud Function → email), PDF layout spec, trace-CC rationale
- [`PDF_REFACTORING_QUICK_REFERENCE.md`](PDF_REFACTORING_QUICK_REFERENCE.md) — Builder-pattern PDF request reference

---

## API Contracts

> No HTTP/REST endpoint from this screen — it writes a Firestore document consumed asynchronously by a Cloud Function (already documented in [`functions/docs/report-delivery-pdf-email.md`](../../../../../../functions/docs/report-delivery-pdf-email.md) and [`FIREBASE_REPORT_DELIVERY.md`](FIREBASE_REPORT_DELIVERY.md)).

### Firestore write contract (`ReportDeliveryQueueService.TaskPayload`)

| Field | Type | Source |
|-------|------|--------|
| `inspectionId` | `String` | `inspection.id` |
| `inspectionNumber` | `String` | `inspection.inspectionNumber` |
| `recipientEmails` | `[String]` | `selectedRecipients` + trimmed `recipientEmail`, filtered non-empty |
| `location` | `String` | `viewModel.location` |
| `finalStatus` | `String` | `selectedStatus.serverKey` |
| `summaryComments` | `String` | `viewModel.summaryComments` |
| `language` | `String` | `LocalizationManager.shared.currentLanguage.rawValue` |

Verified against [`QueueReportDeliveryUseCase.swift:45-53`](../../../../Domain/UseCases/QueueReportDeliveryUseCase.swift#L45-L53).

---

## Edge Cases & Error Handling

> Verified against [`FinalReportViewModel.swift`](FinalReportViewModel.swift) and [`FinalReportView.swift`](FinalReportView.swift).

| Scenario | Expected Behavior | Handled? |
|----------|------------------|----------|
| `inspection == nil` when sending | Error alert "Không có dữ liệu kiểm tra" | ✅ (both `sendReportViaQueue`, `generateAndSendPDF`) |
| Mail app unavailable (`MailComposerView.canSendMail == false`) | `showMailUnavailableAlert = true` | ✅ — but only checked in the legacy `generateAndSendPDF()` path; `sendReportViaQueue()` (the currently-active path) has no such check since it doesn't need the Mail app |
| No valid recipient email after filtering | `QueueDeliveryError.noRecipients` thrown → localized Vietnamese error shown | ✅ ([`QueueReportDeliveryUseCase.swift:40-43`](../../../../Domain/UseCases/QueueReportDeliveryUseCase.swift#L40-L43)) |
| Photo uploads still in progress on send tap | Send deferred; Upload Status sheet shown; auto-resumes when uploads finish | ✅ ([`FinalReportView.swift:336-361`](FinalReportView.swift#L336-L361)) |
| Firestore/network failure during enqueue | Caught by generic `catch`, `errorAlertMessage` set to `error.localizedDescription` | ✅ ([`FinalReportViewModel.swift:234-238`](FinalReportViewModel.swift#L234-L238)) |
| Status stream yields `.failed` | "Gửi báo cáo thất bại. Vui lòng thử lại." shown | ✅ |
| `markInspectionCompleted()` fails (fetch/update error) | Logged via `logger.error` only — no user-facing alert; the success alert was already shown before this call runs | ⚠️ Partially handled — failure is silent to the user |
| No photos to save | "Không có ảnh để lưu" error alert | ✅ |
| Photo library permission denied | "Không có quyền truy cập thư viện ảnh..." error alert | ✅ |
| Photo save throws (`PHPhotoLibrary` error) | "Không thể lưu ảnh: ..." error alert | ✅ |
| Legacy PDF builder validation fails (`PDFReportBuilderError`) | Distinct "Lỗi validation: ..." error message vs. generic PDF failure | ✅ (legacy path only) |

---

## Test Coverage Notes

| Component | Test File | Coverage |
|-----------|-----------|----------|
| `FinalReportViewModel` | — | ❌ Missing |
| `QueueReportDeliveryUseCase` | — | ❌ Missing |
| `FinalReportView` | — | ❌ Missing |

No test target exists in this repository at the time of writing (`find -iname "*Tests*"` under the project root returned nothing), so there is no existing coverage to report against.

**Suggested test cases:**
- [ ] `sendReportViaQueue()` with no recipients selected and empty `recipientEmail` → `showErrorAlert` true, no Firestore write
- [ ] `sendReportViaQueue()` success path → `showEmailQueuedAlert` true, inspection marked completed, `statusStream` eventually yields `.sent`
- [ ] `statusStream` yields `.failed` → `showErrorAlert` true with the failure message
- [ ] Tapping send while `activeUploadCount > 0` → Upload Status sheet opens, send fires automatically once uploads reach 0
- [ ] `FinalReportStatus.serverKey` round-trips correctly for all three cases
- [ ] `markInspectionCompleted()` failure path — confirm whether a user-facing error should be surfaced (currently silent)

---

## Notes

> Additional context, open questions, or known limitations.

- No Jira ticket is linked to the current branch (`feat/login`); commit history touching this folder (`[Revenue] fix pdf spectfit`, `[Revenue][CRE-] add feature botton sheet report`, etc.) suggests the work was tracked under a different ticket/branch than the one currently checked out.
- `FeatureFlags.useFirebaseReportDelivery` is hardcoded `true` with an explicit `// TODO: revert before commit` comment — confirm with the author whether this is meant to ship as-is or needs to become environment/build-configuration driven before release.
- The hardcoded default `recipientEmail = "freelancerios0502@gmail.com"` and the fully-mocked `availableRecipients` list mean the recipients UI is not yet wired to real data — worth confirming whether this is expected for the current milestone or a known gap.
- `markInspectionCompleted()` failing silently (log-only, no user alert) after the "report queued/sent" success alert has already fired could leave a user believing the inspection is marked complete when it isn't — worth a product/eng decision on whether to surface this.
- This document covers only `FinalReportView.swift`/`FinalReportViewModel.swift` per the explicit `Folder:` scope of this run; deeper dives into the PDF renderer and Cloud Function already exist in the two sibling docs listed above.

---

*Generated by `/ct-ai-document` on 2026-07-08*
