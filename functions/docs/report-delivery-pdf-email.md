# Report Delivery — PDF Generation & Email — Feature Document

> **Jira:** — | **Branch:** `feat/login` | **Generated:** 2026-07-08

> ℹ️ This feature lives in a **Firebase Cloud Functions (TypeScript)** backend, not the iOS MVVM-C app, so the Architecture / Key Files sections below are adapted from the standard iOS template to a Firestore-trigger + Cloud Function shape.
> Jira/Confluence not fetched — no ticket key found in the current branch name (`feat/login`) and no `JIRA`/`CONFLUENCE` params were provided.

---

## PRD Summary

> What the feature does and why it exists.

- **Goal:** Automatically generate a branded PDF inspection report and email it to recipients whenever an inspection report delivery is requested from the iOS app.
- **User story:** As an inspector using the LMS Report iOS app, I want to send a completed inspection report by email so that stakeholders (factory, buyer, etc.) receive a formatted PDF without me having to generate it manually.
- **Acceptance criteria:**
  - Not available — add manually (no Jira ticket linked to this branch)

---

## Business Rules

> Key business constraints and logic that developers must respect, extracted directly from [`index.ts`](../src/index.ts).

| Rule | Description |
|------|-------------|
| Trigger scope | Function only fires on Firestore document **create** in `report_delivery_queue/{taskId}` ([`index.ts:158-165`](../src/index.ts#L158-L165)) — it does **not** fire on document updates. |
| Status lifecycle | Task status transitions `processing` → `sent` \| `failed`, written back onto the same queue document ([`index.ts:183`](../src/index.ts#L183), [`index.ts:231`](../src/index.ts#L231), [`index.ts:235`](../src/index.ts#L235)). |
| Default language | `language` defaults to `"vi"` when absent on the task document; only `"vi"`/`"en"` are recognized, anything else falls back to `"vi"` ([`index.ts:179-181`](../src/index.ts#L179-L181)). |
| Default final status | `finalStatus` defaults to `"pending"` when absent ([`index.ts:177`](../src/index.ts#L177)). |
| Trace-cc safety rule | `requestedBy` is only added as `cc`/`replyTo` when it passes `isValidEmail`; the iOS side can write the literal string `"unknown"` into `requestedBy` when no user is logged in, and handing that to nodemailer risks the whole send being rejected — so it's silently dropped instead ([`index.ts:210-215`](../src/index.ts#L210-L215)). |
| Image compression | Every inspection photo is downloaded then re-encoded via `sharp` (resize to fit 800×600, JPEG quality 70) before being embedded in the PDF ([`index.ts:241-248`](../src/index.ts#L241-L248)). |
| Image fetch batching | Images are downloaded in batches of 5 concurrent requests to avoid memory spikes ([`index.ts:283-292`](../src/index.ts#L283-L292)). |
| PDF storage path | Generated PDF is uploaded to Firebase Storage at `inspections/{inspectionId}/reports/{taskId}.pdf` and that path is written back onto the queue document as `pdfStoragePath` ([`index.ts:198-202`](../src/index.ts#L198-L202)). |
| Defect counts | The Critical/Major/Minor defect table in the PDF is always rendered with zero counts — the comment in code states counts are "not stored server-side" ([`index.ts:592`](../src/index.ts#L592)). |
| PDF font fallback | Custom NotoSans fonts are used if present under `functions/fonts/`; otherwise falls back to built-in Helvetica ([`index.ts:519-524`](../src/index.ts#L519-L524)). |

---

## Architecture Overview

> Event-driven Cloud Function, not MVVM — Firestore trigger → PDF render → Storage upload → email send.

### Key Components

| Layer | File | Role |
|-------|------|------|
| Cloud Function (trigger) | [`functions/src/index.ts`](../src/index.ts) — `processReportQueue` (`index.ts:158`) | `onDocumentCreated` listener on `report_delivery_queue/{taskId}`; orchestrates the whole flow |
| PDF rendering | same file — `generatePDF` (`index.ts:504`) + drawing helpers (`drawCell`, `drawInfoTable`, `drawChecklistTable`, `drawDefectTable`, `drawSectionHeader`, etc.) | Builds the multi-page A4 PDF with `pdfkit` |
| Image pipeline | same file — `prefetchImages` (`index.ts:267`), `downloadImageBuffer` (`index.ts:250`), `compressImageBuffer` (`index.ts:241`) | Downloads and compresses inspection photos before embedding |
| Email | same file — `buildEmailHTML` (`index.ts:680`) | Builds localized HTML email body sent via `nodemailer` (Gmail transport) |
| i18n | same file — `TRANSLATIONS`, `t()` (`index.ts:66-133`) | `vi`/`en` string table for both PDF and email content |
| Secrets | same file — `gmailUser`, `gmailPass` (`index.ts:13-14`) | Bound via `firebase-functions/params` `defineSecret`, injected into the function's `secrets` config |
| Fonts (asset) | [`functions/fonts/NotoSans-Regular.ttf`](../fonts/NotoSans-Regular.ttf), [`functions/fonts/NotoSans-Bold.ttf`](../fonts/NotoSans-Bold.ttf) | Registered with `pdfkit` for Vietnamese-diacritic-safe text rendering |
| iOS producer (upstream, cross-referenced) | [`report_lms/Sources/Data/Services/ReportDeliveryQueueService.swift`](../../report_lms/Sources/Data/Services/ReportDeliveryQueueService.swift) — `enqueue(_:)` | Writes the `report_delivery_queue` document that this function reacts to |
| iOS PDF mirror (design reference, cross-referenced) | [`report_lms/Sources/Data/Services/PDFKitGeneratorService.swift`](../../report_lms/Sources/Data/Services/PDFKitGeneratorService.swift) | Client-side PDF generator the code comment says this server function's layout intentionally mirrors ("Qarma-style layout — mirrors iOS PDFKitGeneratorService", `index.ts:20`) |

### Data Flow

```
iOS: ReportDeliveryQueueService.enqueue(_:)
  → Firestore doc created in `report_delivery_queue/{taskId}` (status: "queued")
  → Cloud Function `processReportQueue` triggers (onDocumentCreated)
    → taskRef.update({ status: "processing" })
    → Read `inspections/{inspectionId}` from Firestore
    → prefetchImages() → download + compress inspection photos
    → generatePDF() → render multi-page A4 PDF (pdfkit)
    → Upload PDF to Storage: inspections/{inspectionId}/reports/{taskId}.pdf
    → taskRef.update({ pdfStoragePath })
    → nodemailer.sendMail() via Gmail (attachment = PDF, html = buildEmailHTML())
    → taskRef.update({ status: "sent", sentAt }) — or { status: "failed", errorMessage } on error
  ← iOS: ReportDeliveryQueueService.statusStream(taskId:) observes status changes
```

---

## Key Files & Symbols

> All files under `functions/` that were changed/added on this branch (git diff `main...HEAD` restricted to `functions/`, excluding `node_modules`).

### Cloud Function (source)
- [`src/index.ts`](../src/index.ts) — entire feature: Firestore trigger, PDF generation, image pipeline, email sending, i18n

### Assets
- [`fonts/NotoSans-Bold.ttf`](../fonts/NotoSans-Bold.ttf) — bold font for PDF headings
- [`fonts/NotoSans-Regular.ttf`](../fonts/NotoSans-Regular.ttf) — regular font for PDF body text

### Build output (generated, not hand-authored)
- `lib/index.js`, `lib/index.js.map` — compiled output of `src/index.ts` via `tsc` (see [`tsconfig.json`](../tsconfig.json))

### Config
- [`package.json`](../package.json) — deps: `firebase-admin`, `firebase-functions`, `nodemailer`, `pdfkit`, `sharp`; Node engine 20
- [`tsconfig.json`](../tsconfig.json) — `strict: true`, `target: es2017`, output to `lib/`
- `package-lock.json` — lockfile

### Related iOS files (not in this diff, referenced for context only)
- [`report_lms/Sources/Data/Services/ReportDeliveryQueueService.swift`](../../report_lms/Sources/Data/Services/ReportDeliveryQueueService.swift) — writes/reads the `report_delivery_queue` collection this function consumes
- [`report_lms/Sources/Domain/UseCases/QueueReportDeliveryUseCase.swift`](../../report_lms/Sources/Domain/UseCases/QueueReportDeliveryUseCase.swift) — use case that calls `enqueue(_:)`
- [`report_lms/Sources/Data/Services/PDFKitGeneratorService.swift`](../../report_lms/Sources/Data/Services/PDFKitGeneratorService.swift) — client-side PDF layout this server function mirrors

---

## API Contracts

> No HTTP/REST endpoints — this is a background Firestore-triggered function (`onDocumentCreated`), not a callable/HTTP function. Per guardrails, no endpoint is invented here.

### Trigger Contract

| Trigger | Path | Region | Timeout | Memory |
|---------|------|--------|---------|--------|
| Firestore `onDocumentCreated` | `report_delivery_queue/{taskId}` | `asia-southeast1` | 120s | 512MiB |

### Input document shape (`ReportTask`, [`index.ts:52-61`](../src/index.ts#L52-L61))

```ts
interface ReportTask {
  inspectionId:     string;
  inspectionNumber: string;
  recipientEmails:  string[];
  location:         string;
  requestedBy:      string;
  finalStatus?:     string;   // "accepted" | "pending" | "rejected"
  summaryComments?: string;
  language?:        string;   // "vi" | "en"
}
```

### Side effects (outputs)

- Firestore: `report_delivery_queue/{taskId}` updated with `status`, `pdfStoragePath`, `sentAt` / `errorMessage`
- Firebase Storage: PDF written to `inspections/{inspectionId}/reports/{taskId}.pdf`
- Email: sent via Gmail SMTP (`nodemailer`) with the PDF as attachment

---

## Edge Cases & Error Handling

> Scenarios that require special handling, verified against the code in [`index.ts`](../src/index.ts).

| Scenario | Expected Behavior | Handled? |
|----------|------------------|----------|
| Queue document has no data (`event.data?.data()` undefined) | Logs error, function returns early — no status update written | ✅ ([`index.ts:172`](../src/index.ts#L172)) |
| Referenced `inspections/{inspectionId}` doc not found | Throws, caught by outer `try/catch`, task marked `failed` with error message | ✅ ([`index.ts:189`](../src/index.ts#L189)) |
| `requestedBy` is not a valid email (e.g. `"unknown"`) | Excluded from `cc`/`replyTo` instead of risking SMTP rejection of the whole send | ✅ ([`index.ts:215`](../src/index.ts#L215)) |
| Individual inspection image fails to download/compress | Skipped with a `console.warn`; PDF still generates without that image | ✅ ([`index.ts:289`](../src/index.ts#L289)) |
| Custom fonts missing from `functions/fonts/` | Falls back to built-in Helvetica/Helvetica-Bold | ✅ ([`index.ts:519-524`](../src/index.ts#L519-L524)) |
| Any error during PDF generation, upload, or email send | Caught by outer `try/catch`; task status set to `failed` with `errorMessage`; if that final `update` itself throws, it's swallowed silently (`catch {}`) | ✅ / ⚠️ ([`index.ts:232-235`](../src/index.ts#L232-L235)) — the inner `catch {}` on the failure-status write has no logging, so a double-failure is silently lost |
| Retrying a `failed` task (`ReportDeliveryQueueService.retryTask`) sets status back to `"queued"` via `updateData` | Cloud Function is `onDocumentCreated` only — it does not listen for document **updates** | ❌ — Not available — add manually / verify: as written, setting status back to `queued` on an existing document does not appear to re-trigger `processReportQueue`, since the trigger type only fires on document creation. Flagged for confirmation, not asserted as a bug. |
| `finalStatus` / `language` absent from the queue document | Defaults to `"pending"` / `"vi"` respectively | ✅ ([`index.ts:177-181`](../src/index.ts#L177-L181)) |

---

## Test Coverage Notes

| Component | Test File | Coverage |
|-----------|-----------|----------|
| `processReportQueue` | — | ❌ Missing — no test files found under `functions/` |
| `generatePDF` | — | ❌ Missing |
| `prefetchImages` / `compressImageBuffer` | — | ❌ Missing |
| `buildEmailHTML` | — | ❌ Missing |

No `test`/`spec` files exist under `functions/` at the time of writing, and `package.json` defines no `test` script.

**Suggested test cases:**
- [ ] Success path: valid queue doc + existing inspection → PDF uploaded, email sent, status `sent`
- [ ] Missing inspection doc → status `failed` with descriptive `errorMessage`
- [ ] `requestedBy = "unknown"` → email sent without `cc`/`replyTo`, no SMTP rejection
- [ ] Image download failure for one of several images → PDF still generates, missing image simply omitted
- [ ] `retryTask` (`status: queued` written via update) → confirm whether `processReportQueue` actually re-fires; add an `onDocumentWritten`/manual re-trigger path if it does not
- [ ] `language` unset or invalid value → falls back to `"vi"` content in both PDF and email

---

## Notes

> Additional context, open questions, or known limitations.

- No Jira ticket is linked to the current branch (`feat/login`); the commit history touching `functions/` (`[Revenue] fix pdf spectfit`, `[Revenue] update feature pdf`, etc.) suggests this work was tracked under a different branch/ticket than the one currently checked out.
- Defect counts (Critical/Major/Minor) are hardcoded to `0, 0, 0` in the generated PDF because that data is not stored server-side — confirm with product/design whether this table should be removed or backed by real data.
- The retry-doesn't-retrigger question above (Edge Cases table) should be verified against actual Firebase trigger behavior before relying on the iOS "Retry" action in production.
- This document only covers `functions/` per the explicit `Folder:` scope of this run; the iOS-side queue/PDF services are referenced for context but were not exhaustively audited.

---

*Generated by `/ct-ai-document` on 2026-07-08*
