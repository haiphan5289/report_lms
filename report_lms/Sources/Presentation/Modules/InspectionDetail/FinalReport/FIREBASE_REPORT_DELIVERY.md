# Firebase Report Delivery — Technical Reference

Tài liệu mô tả toàn bộ luồng gửi báo cáo PDF qua Firebase Cloud Functions.

---

## Tổng quan kiến trúc

```
iOS App                          Firebase                        Email
─────────────────────────────────────────────────────────────────────
FinalReportView
  └─ FinalReportViewModel
       └─ sendReportViaQueue()
            └─ QueueReportDeliveryUseCase
                 └─ ReportDeliveryQueueService
                      └─ Firestore: report_delivery_queue/{taskId}
                                          │
                                          ▼ onCreate trigger
                              Cloud Function: processReportQueue
                                          │
                                          ├─ Fetch inspection from Firestore
                                          ├─ Pre-download field images (batches of 5)
                                          ├─ Compress images (sharp)
                                          ├─ Generate Qarma-style PDF (pdfkit + NotoSans)
                                          └─ Send email (nodemailer + Gmail)
                                                          │
                                                          ▼
                                                   recipientEmails[]
```

---

## iOS Side

### Feature Flag

```swift
// FeatureFlags.swift
static var useFirebaseReportDelivery: Bool { return true }
```

Khi `true`, `FinalReportViewModel.sendReport()` route sang `sendReportViaQueue()` thay vì mở Mail composer.

### Luồng gửi báo cáo

**File:** [FinalReportViewModel.swift](FinalReportViewModel.swift)

```swift
func sendReport() async {
    if FeatureFlags.useFirebaseReportDelivery {
        await sendReportViaQueue()   // Firebase path
    } else {
        await generateAndSendPDF()  // Legacy Mail composer
    }
}
```

`sendReportViaQueue()` làm:
1. Gom `recipientEmail` (text field) + `selectedRecipients` thành 1 list
2. Gọi `QueueReportDeliveryUseCase.execute(inspection:recipients:location:finalStatus:summaryComments:)` → tạo Firestore task document
3. Lắng nghe `statusStream(taskId:)` → cập nhật UI theo trạng thái `queued → processing → sent/failed`

### Firestore Task Document

Collection: `report_delivery_queue`

| Field | Type | Mô tả |
|-------|------|--------|
| `inspectionId` | String | UUID của inspection |
| `inspectionNumber` | String | Mã đơn (INS-...) |
| `recipientEmails` | [String] | Danh sách email nhận |
| `location` | String | Vị trí kiểm tra |
| `finalStatus` | String | `"accepted"` / `"pending"` / `"rejected"` |
| `summaryComments` | String | Ghi chú kết luận của inspector |
| `status` | String | `queued` / `processing` / `sent` / `failed` |
| `requestedAt` | Timestamp | Thời điểm tạo task |
| `requestedBy` | String | Email người gửi |
| `sentAt` | Timestamp | Thời điểm gửi thành công |
| `errorMessage` | String | Lý do thất bại (nếu có) |

---

## Cloud Function

**File:** [functions/src/index.ts](../../../../../functions/src/index.ts)

**Trigger:** `onDocumentCreated("report_delivery_queue/{taskId}")`  
**Region:** `asia-southeast1`  
**Timeout:** 120s | **Memory:** 512MiB

### Cấu hình secrets

```bash
firebase functions:secrets:set GMAIL_USER          # tài khoản Gmail gửi mail
firebase functions:secrets:set GMAIL_APP_PASSWORD  # App Password (2FA)
```

### Luồng xử lý

```
1. Cập nhật status → "processing"
2. Fetch inspection document từ Firestore (collection: "inspections")
3. prefetchImages() — tải field.imageURLs theo batches 5 ảnh/lần
4. compressImageBuffer() — resize về max 800×600, JPEG 70%
5. generatePDF() — Qarma-style layout với pdfkit + NotoSans fonts
6. nodemailer.sendMail() — đính kèm PDF, gửi đến recipientEmails
                            + cc/replyTo = requestedBy (xem § Trace Email)
7. Cập nhật status → "sent" | "failed"
```

---

## Trace Email (CC người gửi)

Mỗi email báo cáo tự động **CC** cho chính người đã bấm gửi (`requestedBy`, lấy từ `Auth.auth().currentUser?.email` lúc enqueue — [`ReportDeliveryQueueService.swift:82`](../../../../../Sources/Data/Services/ReportDeliveryQueueService.swift#L82)), để họ luôn có 1 bản trong hộp thư tự tra lại sau này. `replyTo` cũng trỏ về `requestedBy` — người nhận bấm "Reply" sẽ về đúng người gửi, không phải hộp mail chung `GMAIL_USER`.

```ts
// functions/src/index.ts
const traceEmail = isValidEmail(requestedBy) ? requestedBy : undefined;

await transporter.sendMail({
  from: `"LMS Report" <${gmailUser.value()}>`,   // vẫn 1 tài khoản Gmail cố định
  to: recipientEmails.join(", "),
  ...(traceEmail ? { cc: traceEmail, replyTo: traceEmail } : {}),
  ...
});
```

**Vì sao không đổi hẳn "From" thành email người gửi:** Gmail SMTP (`nodemailer` + `service: "gmail"`) yêu cầu xác thực bằng đúng 1 tài khoản cố định (`GMAIL_USER`/`GMAIL_APP_PASSWORD`) — không thể set `From` thành 1 địa chỉ Gmail khác mà tài khoản xác thực không sở hữu (Gmail chặn/spam ngay). Đã cân nhắc dùng Google OAuth (`gmail.send` scope) để gửi thật từ Gmail của user, nhưng bị loại vì:
- User dùng nhiều loại email khác nhau (không chỉ Gmail/1 Google Workspace domain) → OAuth chỉ cover được 1 phần user, vẫn phải giữ đường fallback cho phần còn lại.
- `gmail.send` là sensitive scope — app không giới hạn nội bộ 1 domain thì phải qua Google security assessment (CASA), không tương xứng effort cho 1 tính năng gửi báo cáo nội bộ.

→ CC + Reply-To là giải pháp tự động 100% (không cần user cấp quyền gì thêm), hoạt động với **mọi loại email**, không cần đổi kiến trúc gửi mail.

**Guard "unknown":** `requestedBy` fallback về chuỗi `"unknown"` nếu không có user đăng nhập lúc enqueue. Đưa thẳng `"unknown"` vào `cc`/`replyTo` có thể khiến SMTP từ chối *cả* email (kể cả recipient thật) vì không phải định dạng email hợp lệ. `isValidEmail(requestedBy)` guard trước — nếu không hợp lệ, bỏ qua CC/Reply-To hoàn toàn, email vẫn gửi bình thường cho recipient.

---

## Vietnamese Text Support

Helvetica (pdfkit mặc định) không hỗ trợ Unicode tiếng Việt → ký tự bị vỡ.

**Fix:** Bundle NotoSans TTF vào Cloud Function package.

```
functions/
  fonts/
    NotoSans-Regular.ttf   (~555 KB)
    NotoSans-Bold.ttf      (~562 KB)
```

```typescript
doc.registerFont("R", FONT_REGULAR);
doc.registerFont("B", FONT_BOLD);
```

Path `__dirname` khi runtime trỏ đến `lib/`, nên `..` để lên `functions/`.

---

## PDF Layout (Qarma Style)

Cả hai delivery path (local preview và Firebase) đều dùng cùng Qarma-style layout.

### Cấu trúc trang

**Trang 1 — Cover**

```
┌──────────────────────────────────────────────────────────────────┐
│ Inspection report, Final: INS-XXXX  (grey, 11pt)                │
│ INS-XXXX: Product Name  (bold, 20pt)                             │
├──────────────────────────────────────────────────────────────────┤
│ Inspector:        Name   │  Inspection Date: dd/mm/yyyy          │
│ Planned Sample:   N/N    │  Order Qty:       N                   │
│ Location:         ...    │  Checklist Name:  Final CheckList     │
│ Planned Date:     ...    │  Sampling Method: 100% inspection     │
│ Supplier Name:    ...    (spans full width)                       │
├──────────────────────────────────────────────────────────────────┤
│ Inspector Conclusion  [ACCEPTED]  Notes text...                  │
├──────────────────────────────────────────────────────────────────┤
│████████████  Status: ACCEPTED  ██████████████████████████████████│
├──────────────────────────────────────────────────────────────────┤
│ SUMMARY                                                          │
│ ┌──────────────────────────────────────────────┬────────┐        │
│ │ Checklist Section                            │ Status │        │
│ ├──────────────────────────────────────────────┼────────┤        │
│ │ 1   Section Name                             │   ✓    │        │
│ │ 2   Section Name                             │   —    │        │
│ └──────────────────────────────────────────────┴────────┘        │
│ ┌────────────────────────┬──────────┬────────┬───────┐           │
│ │                        │ CRITICAL │  MAJOR │ MINOR │           │
│ ├────────────────────────┼──────────┼────────┼───────┤           │
│ │  TOTAL                 │    0     │   0    │   0   │           │
│ └────────────────────────┴──────────┴────────┴───────┘           │
├──────────────────────────────────────────────────────────────────┤
│ Report created with report_lms.    Order: INS-XXXX, page: 1     │
└──────────────────────────────────────────────────────────────────┘
```

**Trang 2+ — Sections**

Sections có ảnh → bắt đầu trang mới. Sections không có ảnh → tiếp tục trang hiện tại (chỉ sang trang mới nếu không đủ chỗ cho header + 1 field row).

```
┌──────────────────────────────────────────────────────────────────┐
│ 1   Section Title  (bold 14pt)                                   │
│ ──────────────────────────── (blue underline 1.5pt)              │
│                                                                  │
│ 1.1   Field Label  (regular 11pt)                                │
│ ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐     │
│ │  image 1  │  │  image 2  │  │  image 3  │  │  image 4  │     │
│ └───────────┘  └───────────┘  └───────────┘  └───────────┘     │
│                                                                  │
│ 1.2   Next Field                                                 │
│ ┌───────────┐  ┌───────────┐                                     │
│ │  image 5  │  │  image 6  │                                     │
│ └───────────┘  └───────────┘                                     │
├──────────────────────────────────────────────────────────────────┤
│ Report created with report_lms.    Order: INS-XXXX, page: 2     │
└──────────────────────────────────────────────────────────────────┘
```

### Hằng số layout

| Constant | Giá trị | Ghi chú |
|----------|---------|---------|
| `MARGIN` | 40px | Lề nội dung (dùng khi vẽ, không phải PDFDocument margin) |
| `CW` | 515.28px | A4 content width (595.28 − 2×40) |
| `IMGS_PER_ROW` | 4 | Số ảnh mỗi hàng |
| `IMG_GAP` | 8px | Khoảng cách giữa ảnh |
| `IMG_W` | `(CW − 8×3) / 4` ≈ 122.8px | Chiều rộng ảnh |
| `IMG_H` | `IMG_W × 0.75` ≈ 92.1px | Chiều cao ảnh (4:3) |
| `INFO_ROW_H` | 26px | Chiều cao hàng info table |
| `TABLE_ROW_H` | 24px | Chiều cao hàng checklist/defect table |
| `FOOTER_Y` | `PAGE_H − 28` | Vị trí footer |
| `CONTENT_MAX_Y` | `PAGE_H − 46` | Y tối đa trước footer |

### Content Mode ảnh trong lưới 4 cột

Ảnh được vẽ theo kiểu **aspect-fit** (giữ tỉ lệ gốc, căn giữa trong khung `IMG_W × IMG_H`, có khoảng trắng nếu tỉ lệ lệch 4:3) — giống `.scaledToFit()` trong SwiftUI. Trước đây ảnh bị **stretch** (kéo méo) vì `doc.image()` được truyền cả `width`+`height` mà không có `fit` — đã fix ở cả 2 phía:

```ts
// functions/src/index.ts — pdfkit
doc.image(buf, imgX, y, { fit: [IMG_W, IMG_H], align: "center", valign: "center" });
```

```swift
// PDFKitGeneratorService.swift — iOS
drawAspectFit(img.image, in: inset)   // tự tính scale = min(rect.w/img.w, rect.h/img.h), căn giữa
```

### Status Colors

| Status | Color | Hex |
|--------|-------|-----|
| `accepted` | Green | `#33a14a` |
| `pending` | Orange | `#e5990d` |
| `rejected` | Red | `#c62626` |

---

## Image Compression

**Vấn đề:** 25 ảnh full resolution → PDF ~80-100MB → vượt Gmail limit 25MB.

**Fix:** Dùng `sharp` compress + tải theo batch 5 ảnh để tránh OOM trong 512MiB.

```typescript
async function compressImageBuffer(buf: Buffer): Promise<Buffer> {
  try {
    return await sharp(buf)
      .resize(800, 600, { fit: "inside", withoutEnlargement: true })
      .jpeg({ quality: 70 })
      .toBuffer();
  } catch {
    return buf; // fallback về ảnh gốc nếu sharp lỗi
  }
}
```

### Ước tính dung lượng

| Item | Size |
|------|------|
| NotoSans fonts (embedded) | ~1.1 MB |
| PDF structure + text | ~200 KB |
| Mỗi ảnh sau compress | ~80-150 KB |
| **Gmail SMTP limit** | **25 MB** |
| **Số ảnh tối đa (ước tính)** | **~150-200 ảnh** |

---

## Deploy

```bash
cd functions
npm run build          # tsc compile
firebase deploy --only functions
```

> Warning `"could not set up cleanup policy"` không ảnh hưởng deploy.

---

## Testing

### Checklist test

- [ ] Mở Final Report → chọn status (Accepted/Pending/Rejected) → nhập ghi chú
- [ ] Tap **Send Email** → Firestore document tạo với `status: "queued"`, có `finalStatus` và `summaryComments`
- [ ] Firestore update lên `status: "processing"` (function trigger)
- [ ] Email đến inbox với PDF đính kèm
- [ ] Firestore update lên `status: "sent"`
- [ ] PDF trang 1: cover page có info table, status banner đúng màu, checklist table
- [ ] PDF trang 2+: sections có ảnh mở trang mới, ảnh 4 cột; sections không có ảnh tiếp tục trang hiện tại
- [ ] PDF: footer xuất hiện trên mọi trang ("Report created with report_lms.")
- [ ] PDF: tiếng Việt hiển thị đúng (không bị vỡ ký tự)
- [ ] PDF size < 25MB

### Kiểm tra log function

```bash
firebase functions:log --only processReportQueue
```

---

## Cấu trúc files liên quan

```
functions/
  src/index.ts              — Cloud Function logic (Qarma PDF layout)
  fonts/
    NotoSans-Regular.ttf
    NotoSans-Bold.ttf

report_lms/Sources/
  Domain/
    Entities/
      FinalReportStatus.swift        — .accepted/.pending/.rejected + serverKey
    UseCases/
      QueueReportDeliveryUseCase.swift
  Data/
    Services/
      ReportDeliveryQueueService.swift
      PDFKitGeneratorService.swift   — iOS Qarma PDF (mirrors Cloud Function layout)
  Presentation/Modules/InspectionDetail/FinalReport/
    FinalReportView.swift
    FinalReportViewModel.swift
  Common/
    FeatureFlags.swift
```

---

*Last updated: 2026-07-04 — feat/login branch*  
*Changes: Qarma-style PDF layout (cover page, 4-col grid, per-page footer, status banner); finalStatus + summaryComments threaded through queue delivery; fixed blank pages (PDFDocument margins set to 0 so pdfkit auto-break threshold doesn't conflict with FOOTER_Y); smart section page-break (only force new page when section has images or not enough room); trace-CC + Reply-To to requestedBy with "unknown" guard; photo grid switched from stretch to aspect-fit (both Cloud Function and iOS).*
