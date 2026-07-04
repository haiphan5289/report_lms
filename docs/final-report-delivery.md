# Final Report Delivery — Feature Document

> **Jira:** — (không tìm thấy ticket key trong tên branch `feat/login`) | **Branch:** `feat/login` | **Generated:** 2026-07-04
>
> Jira/Confluence data not fetched — không có `JIRA`/`CONFLUENCE` param, và branch hiện tại không mang mã ticket. Tài liệu này được dựng từ code thật (đọc trực tiếp, không suy đoán) ở 2 khu vực được chỉ định: `functions/` (Cloud Function backend) và `report_lms/Sources/Presentation/Modules/InspectionDetail/FinalReport/` (iOS feature), cộng với 2 tài liệu kỹ thuật đã có sẵn cùng thư mục (`FIREBASE_REPORT_DELIVERY.md`, `PDF_REFACTORING_QUICK_REFERENCE.md`) — được dùng làm nguồn tham chiếu bổ sung, không sao chép nguyên văn.

---

## PRD Summary

> What the feature does and why it exists.

- **Goal:** Cho phép inspector hoàn tất một inspection bằng cách tạo báo cáo PDF (layout "Qarma-style") và gửi qua email cho danh sách người nhận, đồng thời đánh dấu inspection là `.completed`.
- **User story:** Là một inspector, tôi muốn xem lại kết luận cuối cùng (Đạt/Chờ xử lý/Không đạt), thêm ghi chú, chọn người nhận, rồi gửi báo cáo PDF qua email — để hoàn tất quy trình kiểm tra mà không cần rời khỏi app.
- **Acceptance criteria:** *Not available — add manually* (không có Jira ticket để trích xuất acceptance criteria gốc). Checklist test thủ công đã có sẵn tại [`FIREBASE_REPORT_DELIVERY.md` § Testing](../report_lms/Sources/Presentation/Modules/InspectionDetail/FinalReport/FIREBASE_REPORT_DELIVERY.md#testing), có thể dùng làm cơ sở.

---

## Business Rules

> Key business constraints and logic that developers must respect (trích xuất từ code, đã verify).

| Rule | Description |
|------|-------------|
| Có 2 đường gửi báo cáo, chọn qua feature flag | `FeatureFlags.useFirebaseReportDelivery` (hiện hard-code `true`, xem [`FeatureFlags.swift:12`](../report_lms/Sources/Common/Helpers/FeatureFlags.swift#L12)) quyết định `sendReport()` route sang `sendReportViaQueue()` (Firebase, server-side render) hay `generateAndSendPDF()` (legacy, mở Mail composer với PDF render tại chỗ trên máy) |
| Bắt buộc có ít nhất 1 email hợp lệ | `QueueReportDeliveryUseCase.execute` throw `QueueDeliveryError.noRecipients` nếu `recipients.map(\.email).filter { !$0.isEmpty }` rỗng — gộp cả `selectedRecipients` (picker) và `recipientEmail` (text field nhập tay) |
| PDF luôn dùng đúng 1 layout ("Qarma-style") dù render ở đâu | iOS (`PDFKitGeneratorService`, local preview/mail) và Cloud Function (`functions/src/index.ts`, server-side) độc lập implement CÙNG một layout — không share code, phải đồng bộ thủ công khi đổi 1 bên |
| `PDFReportRequestBuilder.build()` validate trước khi tạo request | Thiếu `inspection`, `inspectorName`, hoặc `location` → throw `PDFReportBuilderError` tương ứng, chặn không cho tạo PDF với dữ liệu thiếu |
| Đánh dấu inspection hoàn tất SAU khi enqueue, không đợi email gửi xong | `sendReportViaQueue()` gọi `markInspectionCompleted()` ngay sau khi enqueue task thành công (trước khi Cloud Function chạy xong) — xem § Edge Cases về rủi ro liên quan |
| `markInspectionCompleted()` đọc lại inspection tươi từ storage, không dùng snapshot cũ | Comment tại [`FinalReportViewModel.swift:307-308`](../report_lms/Sources/Presentation/Modules/InspectionDetail/FinalReport/FinalReportViewModel.swift#L307-L308): `self.inspection` là snapshot lúc mở màn hình, dùng nó sẽ ghi đè `imageURLs` về `[]` trên Firestore nếu ảnh vừa upload xong sau đó |
| Chỉ ảnh local (chưa remote) mới được lưu vào Photos Library | `FinalReportViewModel.allPhotos` filter `$0.isRemote ? nil : $0.image` — ảnh đã ở Firebase Storage thì không lưu lại vào máy |

---

## Architecture Overview

> MVVM + Clean Architecture layers involved, cộng với 1 Cloud Function backend (Node.js/TypeScript, ngoài phạm vi MVVM iOS).

### Key Components

| Layer | File | Role |
|-------|------|------|
| Presentation | [`FinalReportView.swift`](../report_lms/Sources/Presentation/Modules/InspectionDetail/FinalReport/FinalReportView.swift) | UI: quantities/status/location/summary/notification/email sections, action buttons, save-photos, recipients picker sheet, Mail composer sheet, PDF preview sheet |
| Presentation | [`FinalReportViewModel.swift`](../report_lms/Sources/Presentation/Modules/InspectionDetail/FinalReport/FinalReportViewModel.swift) | `sendReport()` routing, `generateAndPreviewPDF()`/`generateAndSendPDF()` (legacy), `sendReportViaQueue()` (Firebase), `saveAllPhotosToLibrary()` |
| Domain | [`PDFReportRequest.swift`](../report_lms/Sources/Domain/Entities/PDFReportRequest.swift) | DTO — input cho PDF generator, có `isValid`/`validationError` |
| Domain | [`PDFReportRequestBuilder.swift`](../report_lms/Sources/Domain/Entities/PDFReportRequestBuilder.swift) | Builder pattern, validate required fields trước khi build `PDFReportRequest` |
| Domain | [`GenerateHTMLPDFReportUseCase.swift`](../report_lms/Sources/Domain/UseCases/GenerateHTMLPDFReportUseCase.swift) | Use case gọi `PDFGeneratorType` để render PDF (chưa đọc chi tiết trong lượt này — xem Notes) |
| Domain | [`QueueReportDeliveryUseCase.swift`](../report_lms/Sources/Domain/UseCases/QueueReportDeliveryUseCase.swift) | Validate recipients, build `TaskPayload`, gọi `ReportDeliveryQueueService.enqueue`, expose `statusStream(taskId:)` |
| Domain | [`FinalReportStatus.swift`](../report_lms/Sources/Domain/Entities/FinalReportStatus.swift) | `.accepted`/`.pending`/`.rejected`, `serverKey` convert sang ASCII cho Firestore |
| Domain | [`PDFGeneratorType.swift`](../report_lms/Sources/Domain/Repositories/PDFGeneratorType.swift) | Protocol cho PDF generator (chưa đọc chi tiết — xem Notes) |
| Data | [`PDFKitGeneratorService.swift`](../report_lms/Sources/Data/Services/PDFKitGeneratorService.swift) | iOS-side PDF renderer, layout "Qarma-style" — mirror thủ công của Cloud Function |
| Data | [`ReportDeliveryQueueService.swift`](../report_lms/Sources/Data/Services/ReportDeliveryQueueService.swift) | Firestore CRUD cho collection `report_delivery_queue`: `enqueue`, `statusStream`, `allTasksStream`, `deleteTask(s)`, `deleteTasksForInspection`, `retryTask`, `latestSentTask` |
| Backend | [`functions/src/index.ts`](../functions/src/index.ts) | Cloud Function `processReportQueue` — trigger `onDocumentCreated("report_delivery_queue/{taskId}")`, render PDF (pdfkit + NotoSans + sharp), gửi email (nodemailer + Gmail) |

### Data Flow

```
FinalReportView (user chọn status/location/comments/recipients, tap "Gửi báo cáo")
  → FinalReportViewModel.sendReport()
      ├── FeatureFlags.useFirebaseReportDelivery == true (hiện tại luôn true)
      │     → sendReportViaQueue()
      │         → QueueReportDeliveryUseCase.execute(inspection:recipients:location:finalStatus:summaryComments:)
      │             → ReportDeliveryQueueService.enqueue(TaskPayload) → Firestore doc report_delivery_queue/{taskId}
      │         → markInspectionCompleted()   (đọc fresh từ storageService, set .completed)
      │         → for await status in queueDeliveryUseCase.statusStream(taskId:) { ... }
      │             → Firestore onDocumentCreated trigger
      │                 → Cloud Function processReportQueue (functions/src/index.ts)
      │                     ├── Fetch inspection tươi từ Firestore (collection "inspections")
      │                     ├── prefetchImages() — tải field.imageURLs theo batch 5
      │                     ├── compressImageBuffer() — sharp resize 800×600, JPEG 70%
      │                     ├── generatePDF() — Qarma layout, pdfkit + NotoSans
      │                     ├── Upload PDF → Storage: inspections/{id}/reports/{taskId}.pdf
      │                     └── nodemailer.sendMail() → cập nhật status sent/failed
      │         ← statusStream yield .sent | .failed → showEmailSuccessAlert | showErrorAlert
      │
      └── FeatureFlags.useFirebaseReportDelivery == false
            → generateAndSendPDF()  (legacy — build request qua PDFReportRequestBuilder,
                                      generatePDFUseCase.execute, mở MailComposerView tại chỗ)
```

---

## Key Files & Symbols

> Tất cả file trong 2 khu vực chỉ định (`functions/`, `FinalReport/`) cộng các file domain/data liên quan trực tiếp — mọi path đã verify tồn tại bằng `find`/`Read`.

### Presentation
- [`FinalReportView.swift`](../report_lms/Sources/Presentation/Modules/InspectionDetail/FinalReport/FinalReportView.swift) — SwiftUI view chính: `quantitiesSection`, `statusSection`, `locationSection`, `summarySection`, `notificationSection`, `emailSection`, `actionButtonsSection`, `savePhotosSection`, `recipientsPickerView`; sheets: `MailComposerView`, `PDFPreviewView`, upload-status (chia sẻ `inspectionDetailVM.showUploadStatusSheet`)
- [`FinalReportViewModel.swift`](../report_lms/Sources/Presentation/Modules/InspectionDetail/FinalReport/FinalReportViewModel.swift) — `sendReport()`, `sendReportViaQueue()`, `generateAndPreviewPDF()`, `generateAndSendPDF()`, `markInspectionCompleted()`, `saveAllPhotosToLibrary()`

### Domain
- [`PDFReportRequest.swift`](../report_lms/Sources/Domain/Entities/PDFReportRequest.swift) — DTO, `isValid`/`validationError`
- [`PDFReportRequestBuilder.swift`](../report_lms/Sources/Domain/Entities/PDFReportRequestBuilder.swift) — `.with(...)` fluent API + `build()`/`buildWithDefaults()`, `PDFReportBuilderError`
- [`GenerateHTMLPDFReportUseCase.swift`](../report_lms/Sources/Domain/UseCases/GenerateHTMLPDFReportUseCase.swift) — *chưa đọc nội dung chi tiết trong lượt tài liệu này*
- [`QueueReportDeliveryUseCase.swift`](../report_lms/Sources/Domain/UseCases/QueueReportDeliveryUseCase.swift) — `execute(inspection:recipients:location:finalStatus:summaryComments:) async throws -> String`, `statusStream(taskId:) -> AsyncStream<ReportDeliveryStatus>`, `QueueDeliveryError.noRecipients`
- [`FinalReportStatus.swift`](../report_lms/Sources/Domain/Entities/FinalReportStatus.swift) — `enum FinalReportStatus: String, Codable, CaseIterable { accepted, pending, rejected }`, `serverKey`
- [`PDFGeneratorType.swift`](../report_lms/Sources/Domain/Repositories/PDFGeneratorType.swift) — *chưa đọc nội dung chi tiết trong lượt tài liệu này*

### Data
- [`PDFKitGeneratorService.swift`](../report_lms/Sources/Data/Services/PDFKitGeneratorService.swift) — iOS PDF renderer, Qarma-style layout (mirror của Cloud Function)
- [`ReportDeliveryQueueService.swift`](../report_lms/Sources/Data/Services/ReportDeliveryQueueService.swift) — `enqueue`, `statusStream`, `allTasksStream`, `deleteTask(taskId:)`, `deleteTasks(taskIds:)`, `deleteTasksForInspection(inspectionId:)`, `latestSentTask(for:)`, `retryTask(taskId:)`; `struct TaskPayload`; `enum ReportDeliveryStatus`

### Config
- [`FeatureFlags.swift`](../report_lms/Sources/Common/Helpers/FeatureFlags.swift) — `useFirebaseReportDelivery` (hard-code `true`, có `// TODO: revert before commit` — xem Notes)

### Backend (Cloud Functions — Node.js/TypeScript, ngoài MVVM iOS)
- [`functions/src/index.ts`](../functions/src/index.ts) — `processReportQueue` (trigger), `generatePDF`, `prefetchImages`, `compressImageBuffer`, `buildEmailHTML`, các hàm vẽ PDF (`drawInfoTable`, `drawChecklistTable`, `drawDefectTable`, `drawSectionHeader`, `drawConclusionRow`, `drawStatusBanner`)
- [`functions/package.json`](../functions/package.json) — dependencies: `firebase-admin ^12.0.0`, `firebase-functions ^5.0.0`, `nodemailer ^6.9.0`, `pdfkit ^0.15.0`, `sharp ^0.34.5`; Node engine `20`
- `functions/fonts/NotoSans-Regular.ttf`, `functions/fonts/NotoSans-Bold.ttf` — font Unicode tiếng Việt bundle theo Cloud Function (Helvetica mặc định của pdfkit không hỗ trợ tiếng Việt)

### Docs đã có sẵn (tham chiếu kỹ thuật sâu hơn, không lặp lại ở đây)
- [`FIREBASE_REPORT_DELIVERY.md`](../report_lms/Sources/Presentation/Modules/InspectionDetail/FinalReport/FIREBASE_REPORT_DELIVERY.md) — luồng đầy đủ, cấu trúc Firestore task document, layout PDF chi tiết, ước tính dung lượng, hướng dẫn deploy/test
- [`PDF_REFACTORING_QUICK_REFERENCE.md`](../report_lms/Sources/Presentation/Modules/InspectionDetail/FinalReport/PDF_REFACTORING_QUICK_REFERENCE.md) — Builder pattern quick reference, common pitfalls

---

## API Contracts

> Không có REST API target nào trong diff — đây là kiến trúc Firestore-trigger, không phải HTTP endpoint. Liệt kê theo đúng bản chất thực tế thay vì ép vào bảng REST.

**Firestore collection:** `report_delivery_queue` (ghi bởi iOS qua `ReportDeliveryQueueService.enqueue`, đọc/update bởi Cloud Function)

| Field | Type | Ghi bởi | Mô tả |
|-------|------|---------|--------|
| `inspectionId` | String | iOS | ID inspection |
| `inspectionNumber` | String | iOS | Mã đơn (INS-...) |
| `recipientEmails` | [String] | iOS | Danh sách email nhận |
| `location` | String | iOS | Vị trí kiểm tra |
| `finalStatus` | String | iOS | `accepted` / `pending` / `rejected` (`FinalReportStatus.serverKey`) |
| `summaryComments` | String | iOS | Ghi chú kết luận |
| `language` | String | iOS | `LocalizationManager.shared.currentLanguage.rawValue` |
| `status` | String | Cả 2 | `queued` (iOS ghi lúc tạo) → `processing` → `sent`/`failed` (Cloud Function update) |
| `requestedAt` | Timestamp | iOS | Server timestamp lúc tạo |
| `requestedBy` | String | iOS | `Auth.auth().currentUser?.email ?? "unknown"` |
| `sentAt` | Timestamp | Cloud Function | Lúc gửi email thành công |
| `errorMessage` | String | Cloud Function | Lý do fail (nếu có) |
| `pdfStoragePath` | String | Cloud Function | `inspections/{id}/reports/{taskId}.pdf` trên Firebase Storage |

**Cloud Function trigger:** `onDocumentCreated("report_delivery_queue/{taskId}")` — region `asia-southeast1`, timeout `120s`, memory `512MiB`, secrets `GMAIL_USER`/`GMAIL_APP_PASSWORD` (xem [`functions/src/index.ts:154-161`](../functions/src/index.ts#L154-L161)).

---

## Edge Cases & Error Handling

| Scenario | Expected Behavior | Handled? |
|----------|------------------|----------|
| Không nhập email nào (cả picker lẫn text field đều rỗng) | `QueueDeliveryError.noRecipients` → `errorAlertMessage` + `showErrorAlert` | ✅ |
| Mail app không khả dụng (chỉ ảnh hưởng legacy path) | `MailComposerView.canSendMail == false` → `showMailUnavailableAlert` | ✅ |
| Thiếu `inspection`/`inspectorName`/`location` khi build PDF request (legacy path) | `PDFReportRequestBuilder.build()` throw `PDFReportBuilderError` tương ứng → `errorAlertMessage` | ✅ |
| Cloud Function không tìm thấy inspection (`inspectionId` sai/đã xoá) | `throw new Error(...)`, catch → `taskRef.update({ status: "failed", errorMessage })` | ✅ |
| Ảnh field lỗi khi tải/nén (URL hỏng, timeout > 10s) | `prefetchImages` catch từng ảnh riêng lẻ, log warning, bỏ qua — không fail cả PDF | ✅ |
| PDF vượt giới hạn Gmail 25MB (quá nhiều ảnh) | Không có check dung lượng tường minh trước khi gửi — chỉ giảm rủi ro bằng nén ảnh (800×600, JPEG 70%); xem ước tính "~150-200 ảnh tối đa" trong `FIREBASE_REPORT_DELIVERY.md` | ❌ (chỉ giảm thiểu, không chặn cứng) |
| **Ảnh vẫn đang upload lúc user bấm "Gửi báo cáo" / "Hoàn tất"** | `sendReportViaQueue()` không check `activeUploadCount`/`uploadSessions` trước khi enqueue + `markInspectionCompleted()`. Cloud Function tuy đọc Firestore tươi (không dùng snapshot cũ) nhưng nếu ảnh chưa kịp ghi `imageURLs` lên Firestore tại thời điểm Cloud Function chạy, ảnh đó vẫn bị thiếu trong PDF — cùng bản chất với gap đã ghi nhận ở `InspectionDetailViewModel.submitInspection()` (xem [`IMAGE_CACHE_WORKFLOW.md` § Giới hạn đã biết](../report_lms/Sources/Presentation/Modules/InspectionDetail/IMAGE_CACHE_WORKFLOW.md)) | ❌ |
| Retry khi task `failed` | `ReportDeliveryQueueService.retryTask(taskId:)` set lại `status: queued` để Cloud Function xử lý lại — nhưng **không có UI nào trong `FinalReportView`/`FinalReportViewModel` gọi hàm này** (chỉ tìm thấy định nghĩa, chưa xác nhận call site trong `FinalReport/`) | ⚠️ Chưa xác nhận đầy đủ — cần kiểm tra thêm (có thể nằm ở màn hình khác quản lý queue) |

---

## Test Coverage Notes

| Component | Test File | Coverage |
|-----------|-----------|----------|
| `FinalReportViewModel` | — | ❌ Missing (không tìm thấy file test trong `FinalReport/`) |
| `QueueReportDeliveryUseCase` | — | ❌ Missing |
| `ReportDeliveryQueueService` | — | ❌ Missing |
| `PDFReportRequestBuilder` | — | ❌ Missing |
| `functions/src/index.ts` (Cloud Function) | — | ❌ Missing (không có test runner nào khai báo trong `functions/package.json`) |

> Checklist test **thủ công** (manual QA) đã có sẵn và khá đầy đủ tại [`FIREBASE_REPORT_DELIVERY.md` § Testing](../report_lms/Sources/Presentation/Modules/InspectionDetail/FinalReport/FIREBASE_REPORT_DELIVERY.md#testing) — nên dùng làm nền cho unit/integration test thay vì viết lại từ đầu.

**Suggested test cases:**
- [ ] `QueueReportDeliveryUseCase.execute` — recipients rỗng → throw `QueueDeliveryError.noRecipients`
- [ ] `PDFReportRequestBuilder.build()` — thiếu từng field bắt buộc → đúng `PDFReportBuilderError` tương ứng
- [ ] `FinalReportViewModel.sendReport()` — verify route đúng theo `FeatureFlags.useFirebaseReportDelivery`
- [ ] `FinalReportViewModel.allPhotos` — chỉ trả về ảnh `!isRemote`, loại bỏ ảnh đã upload

---

## Notes

> Additional context, open questions, or known limitations — chỉ liệt kê điều đã verify được, không suy đoán.

- `FeatureFlags.useFirebaseReportDelivery` hiện hard-code `true` kèm comment `// TODO: revert before commit` ([`FeatureFlags.swift:12`](../report_lms/Sources/Common/Helpers/FeatureFlags.swift#L12)) — comment phía trên nó mô tả một cơ chế env-var (`USE_FIREBASE_DELIVERY=1`) nhưng code hiện tại **không đọc** biến môi trường đó, chỉ trả `true` vô điều kiện. Nên xác nhận với người maintain trước khi coi đây là "flag thật" hay chỉ là code tạm.
- `GenerateHTMLPDFReportUseCase.swift` và `PDFGeneratorType.swift` đã xác nhận tồn tại (qua `find`) nhưng **chưa đọc nội dung** trong lượt tạo tài liệu này — nếu cần mô tả chi tiết luồng render PDF phía iOS, nên đọc bổ sung 2 file này.
- Hai file layout PDF (iOS `PDFKitGeneratorService.swift` và Cloud Function `functions/src/index.ts`) triển khai **độc lập, không share code** — mọi thay đổi layout phải sửa cả 2 nơi thủ công (đã ghi nhận trong `PDF_REFACTORING_QUICK_REFERENCE.md`).
- `ReportDeliveryQueueService.retryTask(taskId:)` tồn tại nhưng chưa xác nhận có UI nào gọi nó trong `FinalReport/` — cần kiểm tra thêm (có thể thuộc một màn hình quản lý delivery queue riêng, ngoài phạm vi 2 folder được chỉ định).
- Không tìm thấy check dung lượng PDF trước khi gửi email (giới hạn Gmail 25MB) — chỉ có ước tính lý thuyết trong doc kỹ thuật, chưa có guard cứng trong code.

---

*Generated by `/ct-ai-document` on 2026-07-04*
