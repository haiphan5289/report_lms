# Orders — Xem Chi Tiết & PDF Báo Cáo

## 📋 Tổng quan

Tài liệu này mô tả workflow **tap vào Order → xem bottom sheet chi tiết → xem PDF báo cáo đã gửi**.

---

## 🏗️ Kiến trúc tổng quan

```
┌─────────────────────────────────────────────────────────────────┐
│                       Presentation Layer                         │
│                                                                   │
│  OrdersView                                                       │
│  ├── OrderCardView          ← tap → inspectionToDetail           │
│  └── OrderDetailBottomSheet ← nhận Inspection, load task        │
│       ├── heroHeader        (inspectionNumber, status)           │
│       ├── detailSection     (product, factory, quantity, date)   │
│       └── pdfSection        ← query sentTask → show "Xem PDF"   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                        Data Layer                                 │
│  ReportDeliveryQueueService.latestSentTask(for:)                 │
│  FirebaseStorageService.downloadData(fromPath:)                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                  Firebase Backend                                  │
│  Firestore: report_delivery_queue/{taskId}                       │
│  Storage:   inspections/{inspectionId}/reports/{taskId}.pdf      │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Workflow Chi Tiết

### Phần 1 — iOS: Tap Card → Bottom Sheet

#### Bước 1: User Tap OrderCardView

**File:** `OrdersView.swift` — `OrderCardView`

```swift
// Gesture dùng .gesture (không phải .simultaneousGesture)
// → child Button (trash) tự xử lý tap riêng, không trigger card tap
.gesture(
    DragGesture(minimumDistance: 0)
        .updating($cardPressed) { _, state, _ in state = true }
        .onEnded { _ in onTap() }
)
```

> ⚠️ **Lưu ý quan trọng**: Dùng `.gesture` thay vì `.simultaneousGesture`.
> Nếu dùng `.simultaneousGesture`, tap vào nút Delete sẽ đồng thời trigger
> cả bottom sheet (bug UX). `.gesture` cho phép child Button ưu tiên gesture.

**Scale effect khi nhấn giữ:**
```swift
.scaleEffect(cardPressed ? 0.97 : 1.0)
.animation(.spring(response: 0.25, dampingFraction: 0.7), value: cardPressed)
```

#### Bước 2: OrdersView Mở Sheet

**File:** `OrdersView.swift`

```swift
@State private var inspectionToDetail: Inspection?

// Trong orderList:
OrderCardView(
    inspection: inspection,
    onTap: { inspectionToDetail = inspection },  // ← set để mở sheet
    onDelete: { inspectionToDelete = inspection }
)

// Modifier mở bottom sheet:
.sheet(item: $inspectionToDetail) { inspection in
    OrderDetailBottomSheet(inspection: inspection)
}
```

#### Bước 3: OrderDetailBottomSheet Hiển Thị

**File:** `OrderDetailBottomSheet.swift`

Bottom sheet dùng `presentationDetents([.large])` — full screen.

Progressive reveal animation với stagger 120ms:
```
headerVisible  → contentVisible (delay 120ms) → pdfSectionVisible (delay 240ms)
```

```swift
.task {
    withAnimation { headerVisible = true }
    try? await Task.sleep(for: .milliseconds(120))
    withAnimation { contentVisible = true }
    try? await Task.sleep(for: .milliseconds(120))
    withAnimation { pdfSectionVisible = true }
    await loadDeliveryTask()  // ← load sau khi UI đã animate xong
}
```

---

### Phần 2 — iOS: Load Trạng Thái PDF

#### Bước 4: Query Sent Task

**File:** `OrderDetailBottomSheet.swift`

```swift
private func loadDeliveryTask() async {
    isLoadingTask = true
    taskLoadError = nil
    defer { isLoadingTask = false }
    do {
        sentTask = try await deliveryService.latestSentTask(for: inspection.id)
    } catch {
        taskLoadError = "Không thể tải thông tin: \(error.localizedDescription)"
    }
}
```

**File:** `ReportDeliveryQueueService.swift`

```swift
func latestSentTask(for inspectionId: String) async throws -> ReportDeliveryTask? {
    let snapshot = try await db
        .collection(Self.collectionName)
        .whereField("inspectionId", isEqualTo: inspectionId)  // chỉ 1 filter
        .getDocuments()
    return snapshot.documents
        .compactMap { ReportDeliveryTask(from: $0.data(), id: $0.documentID) }
        .filter { $0.status == .sent }       // filter client-side
        .sorted { ($0.sentAt ?? .distantPast) > ($1.sentAt ?? .distantPast) }
        .first
}
```

> ⚠️ **Tại sao không dùng compound Firestore query?**
>
> Query ban đầu dùng:
> ```swift
> .whereField("status", isEqualTo: "sent")
> .order(by: "sentAt", descending: true)
> ```
> Firestore yêu cầu **composite index** cho compound query (2+ `whereField` + `order(by:)`).
> Index này không tự động tạo → query bị lỗi im lặng vì `try?` swallow error.
>
> **Fix**: Chỉ filter theo `inspectionId` trên Firestore (single-field index tự động),
> rồi filter `status == .sent` + sort theo `sentAt` client-side.

#### Bước 5: PDF Section Hiển Thị

**File:** `OrderDetailBottomSheet.swift`

| State | Hiển thị |
|---|---|
| `isLoadingTask == true` | ProgressView + "Đang kiểm tra..." |
| `taskLoadError != nil` | Icon lỗi + message lỗi |
| `sentTask != nil` | `sentPDFRow(task:)` |
| `sentTask == nil` | "Chưa có báo cáo PDF nào được gửi" |

Trong `sentPDFRow`:
- Nếu `task.pdfStoragePath != nil` → hiện nút **"Xem PDF"**
- Nếu `task.pdfStoragePath == nil` → hiện "PDF đang được xử lý trên server"
  (task cũ gửi trước khi deploy Cloud Function mới)

---

### Phần 3 — iOS: Tải & Mở PDF

#### Bước 6: User Tap "Xem PDF"

**File:** `OrderDetailBottomSheet.swift`

```swift
LMSButton(
    "Xem PDF",
    icon: "eye",
    variant: .primary,
    size: .medium,
    isLoading: $isDownloadingPDF  // ← Binding<Bool>, cần $ prefix
) {
    Task { await downloadAndShowPDF(task: task) }
}
```

#### Bước 7: Download PDF từ Firebase Storage

```swift
private func downloadAndShowPDF(task: ReportDeliveryTask) async {
    guard let path = task.pdfStoragePath else { return }
    isDownloadingPDF = true
    downloadError = nil
    defer { isDownloadingPDF = false }
    do {
        pdfData = try await storageService.downloadData(fromPath: path)
        showPDFPreview = true  // ← trigger .sheet để mở PDFPreviewView
    } catch {
        downloadError = "Không thể tải PDF: \(error.localizedDescription)"
    }
}
```

**File:** `FirebaseStorageService.swift`

```swift
func downloadData(fromPath path: String) async throws -> Data {
    let ref = storage.reference().child(path)
    return try await ref.data(maxSize: 20 * 1024 * 1024) // 20MB
}
```

> Auth được xử lý tự động bởi Firebase SDK — không cần download URL hay token thủ công.

#### Bước 8: Mở PDFPreviewView

```swift
.sheet(isPresented: $showPDFPreview) {
    if let data = pdfData {
        PDFPreviewView(
            pdfData: data,
            fileName: "Bao_cao_kiem_tra_\(inspection.inspectionNumber).pdf"
        )
    }
}
```

---

### Phần 4 — Backend: Cloud Function Lưu PDF

**File:** `functions/src/index.ts`

Sau khi tạo PDF buffer và trước khi gửi email, Cloud Function upload file lên Firebase Storage:

```typescript
// Upload PDF lên Storage
const storagePath = `inspections/${inspectionId}/reports/${taskId}.pdf`;
const bucket = admin.storage().bucket();
const file = bucket.file(storagePath);
await file.save(pdfBuffer, { metadata: { contentType: "application/pdf" } });

// Lưu path vào Firestore để iOS có thể download sau
await taskRef.update({ pdfStoragePath: storagePath });
console.log(`[${taskId}] PDF uploaded to Storage: ${storagePath}`);
```

**Storage path pattern:**
```
inspections/{inspectionId}/reports/{taskId}.pdf
```

---

## 📊 Data Flow Đầy Đủ

```
[User tap OrderCardView]
         │
         ▼
[OrdersView: inspectionToDetail = inspection]
         │
         ▼
[OrderDetailBottomSheet: animate in, loadDeliveryTask()]
         │
         ▼
[Firestore query: report_delivery_queue WHERE inspectionId == id]
         │
         ├── not found ──→ "Chưa có báo cáo PDF"
         │
         ▼ found (status == .sent)
[sentTask với pdfStoragePath]
         │
         ├── pdfStoragePath == nil ──→ "PDF đang được xử lý trên server"
         │
         ▼ pdfStoragePath != nil
[Hiện nút "Xem PDF"]
         │
         ▼ user tap
[FirebaseStorageService.downloadData(fromPath:)]
         │
         ▼
[PDFPreviewView(pdfData:fileName:)]
```

---

## 📁 File Structure

```
report_lms/
├── functions/src/
│   └── index.ts                          ← upload PDF to Storage, save pdfStoragePath
│
└── Sources/
    ├── Domain/Entities/
    │   └── ReportDeliveryTask.swift      ← thêm var pdfStoragePath: String?
    │
    ├── Data/Services/
    │   ├── ReportDeliveryQueueService.swift  ← latestSentTask(for:)
    │   └── FirebaseStorageService.swift      ← downloadData(fromPath:)
    │
    └── Presentation/Modules/Orders/
        ├── OrdersView.swift              ← OrderCardView tap, sheet(item: $inspectionToDetail)
        └── OrderDetailBottomSheet.swift  ← bottom sheet UI + PDF download flow
```

---

## 🐛 Debugging

### PDF không hiển thị sau khi gửi email

1. **Kiểm tra Firestore** → `report_delivery_queue/{taskId}` → có field `pdfStoragePath` không?
   - Không có → Cloud Function cũ đang chạy (chưa deploy phiên bản mới)
   - Có → tiếp tục bước 2

2. **Kiểm tra Firebase Storage** → `inspections/{inspectionId}/reports/{taskId}.pdf` → file có tồn tại không?

3. **Kiểm tra log lỗi trong bottom sheet** → nếu query lỗi, lỗi được hiển thị thay vì im lặng

4. **Task cũ** (gửi trước khi deploy Cloud Function mới): field `pdfStoragePath` không có → bottom sheet hiện "PDF đang được xử lý trên server" → cần gửi lại để tạo task mới

### Delete button mở bottom sheet

Nguyên nhân: dùng `.simultaneousGesture` → cả Delete button và card tap đều fire.

Fix: đổi sang `.gesture` trên card — SwiftUI ưu tiên child Button khi có conflict.

---

## ✅ Checklist Deploy

- [ ] Build TypeScript: `cd functions && npm run build`
- [ ] Deploy: `npm run deploy`
- [ ] Kiểm tra Firestore document sau khi gửi → có `pdfStoragePath` field
- [ ] Kiểm tra Firebase Storage → file PDF xuất hiện
- [ ] Test iOS: tap card → bottom sheet → "Xem PDF" button → PDF mở

---

**Last Updated:** 2026-06-14
**Version:** 2.0.0
