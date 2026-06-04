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
                                          ├─ Pre-download field images
                                          ├─ Compress images (sharp)
                                          ├─ Generate PDF (pdfkit + NotoSans)
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

**File:** [FinalReportViewModel.swift](report_lms/Sources/Presentation/Modules/InspectionDetail/FinalReport/FinalReportViewModel.swift)

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
2. Gọi `QueueReportDeliveryUseCase.execute(inspection:recipients:location:)` → tạo Firestore task document
3. Lắng nghe `statusStream(taskId:)` → cập nhật UI theo trạng thái `queued → processing → sent/failed`

### Firestore Task Document

Collection: `report_delivery_queue`

| Field | Type | Mô tả |
|-------|------|--------|
| `inspectionId` | String | UUID của inspection |
| `inspectionNumber` | String | Mã đơn (INS-...) |
| `recipientEmails` | [String] | Danh sách email nhận |
| `location` | String | Vị trí kiểm tra |
| `status` | String | `queued` / `processing` / `sent` / `failed` |
| `requestedAt` | Timestamp | Thời điểm tạo task |
| `requestedBy` | String | Email người gửi |
| `sentAt` | Timestamp | Thời điểm gửi thành công |
| `errorMessage` | String | Lý do thất bại (nếu có) |

---

## Cloud Function

**File:** [functions/src/index.ts](functions/src/index.ts)

**Trigger:** `onDocumentCreated("report_delivery_queue/{taskId}")`  
**Region:** `asia-southeast1`  
**Timeout:** 120s | **Memory:** 512MiB

### Cấu hình secrets

```bash
firebase functions:secrets:set GMAIL_USER      # tài khoản Gmail gửi mail
firebase functions:secrets:set GMAIL_APP_PASSWORD  # App Password (2FA)
```

### Luồng xử lý

```
1. Cập nhật status → "processing"
2. Fetch inspection document từ Firestore (collection: "inspections")
3. prefetchImages() — tải tất cả field.imageURLs song song
4. compressImageBuffer() — resize về max 800×600, JPEG 70%
5. generatePDF() — tạo PDF với pdfkit + NotoSans fonts
6. nodemailer.sendMail() — đính kèm PDF, gửi đến recipientEmails
7. Cập nhật status → "sent" | "failed"
```

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
// Đăng ký font trong generatePDF()
const FONT_REGULAR = path.join(__dirname, "..", "fonts", "NotoSans-Regular.ttf");
const FONT_BOLD    = path.join(__dirname, "..", "fonts", "NotoSans-Bold.ttf");

doc.registerFont("R", FONT_REGULAR);
doc.registerFont("B", FONT_BOLD);
```

Path `__dirname` khi runtime trỏ đến `lib/`, nên `..` để lên `functions/`.

---

## PDF Layout

Layout khớp với iOS `PDFKitGeneratorService.swift`.

### Cấu trúc trang

```
┌─────────────────────────────────────────────────┐
│ Người kiểm tra: ...    │  Ngày kiểm tra: ...    │
│ Số lượng mẫu: ...      │  Số lượng đơn hàng: .. │
│ Vị trí: ...            │  Tên biểu mẫu: ...     │
│ Ngày dự kiến: ...      │  Phương pháp: ...      │
│ Tên nhà máy: ...                                 │
├─────────────────────────────────────────────────┤
│ Báo cáo kiểm tra #INS-XXXX  (bold, 22pt)        │
│ Ngày tạo: dd/MM/yyyy HH:mm  (gray, 10pt)        │
├─────────────────────────────────────────────────┤
│ Tóm tắt lỗi                                     │
│ ┌─────────┬──────────┬────────┬────────────┐   │
│ │         │ CRITICAL │  MAJOR │    MINOR   │   │
│ ├─────────┼──────────┼────────┼────────────┤   │
│ │  TOTAL  │    n     │   n    │     n      │   │
│ └─────────┴──────────┴────────┴────────────┘   │
├─────────────────────────────────────────────────┤
│ Section Title (bold 14pt)                       │
│ ─────────────────────── (blue underline 2pt)    │
│   Field Label (regular 12pt)                    │
│   ┌──────────────┐  ┌──────────────┐           │
│   │    image 1   │  │    image 2   │  (4:3)    │
│   └──────────────┘  └──────────────┘           │
│   ┌──────────────┐                             │
│   │    image 3   │                             │
│   └──────────────┘                             │
└─────────────────────────────────────────────────┘
```

### Hằng số layout

| Constant | Giá trị | Ghi chú |
|----------|---------|---------|
| `MARGIN` | 40px | Lề 4 phía |
| `PAGE_W` | 515.28px | A4 content width (595.28 - 2×40) |
| `IMG_W` | `(PAGE_W - 12) / 2` | ~251px |
| `IMG_H` | `IMG_W × 0.75` | ~188px (4:3) |
| `IMG_GAP` | 12px | Khoảng cách giữa 2 ảnh |

---

## Image Compression

**Vấn đề:** 25 ảnh full resolution → PDF ~80-100MB → vượt Gmail limit 25MB.

**Fix:** Dùng `sharp` compress trước khi embed vào PDF.

```typescript
import sharp from "sharp";

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

Để tăng giới hạn hơn nữa, giảm quality hoặc max size:
```typescript
.resize(600, 450, ...)   // thay vì 800×600
.jpeg({ quality: 60 })  // thay vì 70
```

---

## Deploy

```bash
cd functions
npm run build          # tsc compile
firebase deploy --only functions
```

Package size khi deploy: ~655 KB (bao gồm fonts + sharp).

> Warning `"could not set up cleanup policy"` là không ảnh hưởng deploy — function vẫn update thành công.

---

## Testing

### Temporary test email (revert trước production)

**File:** [FinalReportViewModel.swift:87](report_lms/Sources/Presentation/Modules/InspectionDetail/FinalReport/FinalReportViewModel.swift#L87)

```swift
// TODO: Remove before production
self.recipientEmail = "freelancerios0502@gmail.com"
```

### Checklist test

- [ ] Mở Final Report → email field tự fill `freelancerios0502@gmail.com`
- [ ] Tap **Send Email** → Firestore document tạo với `status: "queued"`
- [ ] Firestore update lên `status: "processing"` (function trigger)
- [ ] Email đến inbox với PDF đính kèm
- [ ] Firestore update lên `status: "sent"`
- [ ] PDF: tiếng Việt hiển thị đúng (không bị vỡ ký tự)
- [ ] PDF: ảnh embed 2 cột, tỉ lệ 4:3
- [ ] PDF size < 25MB (kiểm tra qua email client)

### Kiểm tra log function

```bash
firebase functions:log --only processReportQueue
```

---

## Cấu trúc files liên quan

```
functions/
  src/index.ts              — Cloud Function logic
  fonts/
    NotoSans-Regular.ttf
    NotoSans-Bold.ttf

report_lms/Sources/
  Domain/
    UseCases/QueueReportDeliveryUseCase.swift
  Data/
    Services/ReportDeliveryQueueService.swift
  Presentation/Modules/InspectionDetail/FinalReport/
    FinalReportView.swift
    FinalReportViewModel.swift
  Common/
    FeatureFlags.swift
```

---

*Last updated: 2026-06-04 — feat/login branch*
