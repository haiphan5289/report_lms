# Upload Status Bottom Sheet — Feature Document

> **Jira:** — | **Branch:** `feat/login` | **Generated:** 2026-06-06

---

## PRD Summary

> Cho phép user theo dõi tiến trình upload từng ảnh kiểm tra lên Firebase Storage theo thời gian thực.

- **Goal:** Hiển thị bottom sheet progress upload per-image, grouped by inspection field — triggered khi user nhấn "Gửi Email" trong khi ảnh đang upload
- **User story:** As an inspector, I want to see the upload progress of each photo so that I know my report email will include all photos
- **Acceptance criteria:**
  - [x] Button "Hoàn tất kiểm tra" navigate thẳng vào `FinalReportView` — không block, không check upload
  - [x] Button "Gửi Email" trong `FinalReportView` hiển thị spinner + "Đang tải ảnh (N)..." khi có upload đang chạy
  - [x] Nhấn "Gửi Email" khi đang upload → mở `UploadStatusBottomSheet` + set `pendingEmailSend = true`
  - [x] Khi tất cả upload xong và `pendingEmailSend == true` → auto gửi email
  - [x] Bottom sheet nhóm ảnh theo từng field (section header = field label)
  - [x] Mỗi ảnh hiển thị: thumbnail, "Ảnh N", progress bar %, status icon
  - [x] Progress % là số thực từ Firebase Storage (`fractionCompleted`)
  - [x] 4 trạng thái: `.pending`, `.uploading(progress:)`, `.done`, `.failed`
  - [x] Khi failed: hiển thị ❌ + "Thất bại" — không có retry
  - [x] Session tự xóa khỏi list khi `activeUploadCount == 0`

---

## Business Rules

| Rule | Description |
|------|-------------|
| No retry on failure | Ảnh upload thất bại chỉ hiển thị ❌ — user phải quay lại ValidationView để chụp lại |
| "Hoàn tất" không block | Button "Hoàn tất kiểm tra" luôn navigate thẳng vào FinalReport, bất kể upload đang chạy hay không |
| Auto-send email | Nếu user tap "Gửi Email" khi đang upload → `pendingEmailSend = true` → email tự động gửi khi upload xong (via `FinalReportView.onChange`) |
| Session cleanup | `uploadSessions.removeAll { $0.isComplete }` chỉ chạy khi `activeUploadCount == 0` |
| Count = images, not fields | `totalUploadingImageCount` đếm ảnh còn pending/uploading (không phải số field) — dùng cho UI display count trên button "Gửi Email" |
| `activeUploadCount` là trigger, không phải display | `activeUploadCount` (1 per field session) về 0 SAU `onTaskCompleted` → SAU Firestore write. Dùng làm trigger auto-send và `isUploading` guard. `totalUploadingImageCount` về 0 sớm hơn (per-image doneCb) — **không** dùng làm trigger |
| Concurrent upload throttled | Phase 1 compress: max 4 slots (3 on low-RAM). Phase 2 upload: max 8 slots trên WiFi/5G, 6 trên cellular. Unbounded concurrency gây OOM crash khi nhiều ảnh 12MP (xem § Bugs Fixed) |
| Image resize capped at 1600px | `prepareForUpload(maxDimension: 1600, compressionQuality: 0.8)` — giảm từ 2048px để tối ưu upload speed (~35% nhỏ hơn) mà không ảnh hưởng chất lượng PDF A4 |
| Callbacks are @Sendable | `onImageProgress`, `onImageDone`, `onImageFail` phải `@Sendable` vì được gọi từ trong TaskGroup (non-isolated context) |

---

## Architecture Overview

### Key Components

| Layer | File | Role |
|-------|------|------|
| Presentation | [`UploadStatusBottomSheet.swift`](UploadStatusBottomSheet.swift) | Bottom sheet UI grouped by field |
| Presentation | [`InspectionDetailView.swift`](InspectionDetailView.swift) | Hosts sheet; "Hoàn tất" → `showFinalReport = true` trực tiếp |
| Presentation | [`FinalReport/FinalReportView.swift`](FinalReport/FinalReportView.swift) | "Gửi Email" upload-aware; `@EnvironmentObject InspectionDetailViewModel`; `onChange` auto-send |
| Presentation | [`InspectionDetailViewModel.swift`](InspectionDetailViewModel.swift) | Source of truth: `uploadSessions`, `showUploadStatusSheet`, `totalUploadingImageCount`, `pendingEmailSend` |
| Presentation | [`InspectionValidation/InspectionValidationView.swift`](InspectionValidation/InspectionValidationView.swift) | Nhận và forward 3 callbacks vào VM |
| Presentation | [`InspectionValidation/InspectionValidationViewModel.swift`](InspectionValidation/InspectionValidationViewModel.swift) | Gọi callbacks per-image trong `uploadPhotosAndUpdateField` |
| Domain | [`ImageUploadItem.swift`](../../../Domain/Entities/ImageUploadItem.swift) | `ImageUploadStatus`, `ImageUploadItem`, `FieldUploadSession` models |
| Domain | [`UploadInspectionMediaUseCase.swift`](../../../Domain/UseCases/UploadInspectionMediaUseCase.swift) | `executeWithProgress(imageData:inspectionId:onProgress:)` |
| Data | [`FirebaseStorageService.swift`](../../../Data/Services/FirebaseStorageService.swift) | `uploadImageWithProgress` — `putData` + `observe(.progress)` |
| Data | [`StorageRepositoryType.swift`](../../../Domain/Repositories/StorageRepositoryType.swift) | Protocol: `uploadImageWithProgress(_:path:onProgress:)` |
| Data | [`FirebaseStorageRepository.swift`](../../../Data/Repositories/FirebaseStorageRepository.swift) | Forwards đến `FirebaseStorageService` |

### Data Flow

```
Firebase Storage
  putData(_:) + task.observe(.progress) { snapshot }
    → fractionCompleted (0.0 → 1.0)
      → FirebaseStorageService.uploadImageWithProgress()
        → StorageRepositoryType.uploadImageWithProgress()
          → UploadInspectionMediaUseCase.executeWithProgress()
            → InspectionValidationViewModel.uploadPhotosAndUpdateField()
                progressCb(index, progress) / doneCb(index) / failCb(index)
                  → [weak self] Task { @MainActor }
                    → InspectionDetailViewModel
                        updateImageProgress / markImageDone / markImageFailed
                          → @Published uploadSessions → SwiftUI re-render
                            → UploadStatusBottomSheet (live progress bar)
                              → activeUploadCount → 0
                                → FinalReportView.onChange(activeUploadCount)
                                    pendingEmailSend == true → sendReport() auto-trigger
```

### "Gửi Email" Button Flow

```
User ở FinalReportView, tap "Gửi Email"
  │
  ├─ activeUploadCount == 0  (isUploading = false)
  │     → sendReport() trực tiếp
  │
  └─ activeUploadCount > 0  (isUploading = true)
        → inspectionDetailVM.showUploadStatusSheet = true   (show sheet)
        → inspectionDetailVM.pendingEmailSend = true
              │
              └─ [background] upload hoàn tất
                    → activeUploadCount → 0
                    → FinalReportView.onChange:
                          pendingEmailSend = false
                          sendReport() auto-trigger ✅
```

### Architecture Diagram

```mermaid
graph TD
    A[InspectionDetailView] -->|makeUploadCallbacks| B[InspectionDetailViewModel]
    A -->|onTaskCompleted| B
    A -->|fullScreenCover| J[FinalReportView]
    J -->|@EnvironmentObject| B
    J -->|sheet isPresented| C[UploadStatusBottomSheet]
    C -->|reads| B
    E[InspectionValidationView] -->|onImageProgress/Done/Fail| F[InspectionValidationViewModel]
    F -->|executeWithProgress| G[UploadInspectionMediaUseCase]
    G -->|uploadImageWithProgress| H[FirebaseStorageService]
    H -->|observe .progress| H
    F -->|callbacks @Sendable| B
    B -->|uploadSessions| C
    J -->|onChange totalUploadingImageCount| J
```

---

## Key Files & Symbols

### Presentation — New Files
- [`UploadStatusBottomSheet.swift`](UploadStatusBottomSheet.swift) — Bottom sheet view; `struct UploadStatusBottomSheet: View`, private `struct ImageUploadRow: View`

### Presentation — Modified Files
- [`InspectionDetailViewModel.swift`](InspectionDetailViewModel.swift)
  - `@Published var uploadSessions: [FieldUploadSession]`
  - `@Published var showUploadStatusSheet: Bool`
  - `var pendingEmailSend: Bool` — khi upload xong + flag này true → FinalReportView auto-send email
  - `var totalUploadingImageCount: Int` — computed, counts pending+uploading images
  - `func startUploadSession(fieldId:images:)` — creates session, calls `notifyUploadStarted()`
  - `func makeUploadCallbacks(for:)` — returns 3 `@Sendable` closures for per-image tracking
  - `func updateImageProgress(fieldId:imageIndex:progress:)`
  - `func markImageDone(fieldId:imageIndex:)`
  - `func markImageFailed(fieldId:imageIndex:)`
  - ~~`shouldShowFinalReport`~~ — removed; `pendingFinalReport` — removed; `requestFinalReport()` — removed
- [`InspectionDetailView.swift`](InspectionDetailView.swift) — `@State showFinalReport`; "Hoàn tất" sets `showFinalReport = true` trực tiếp; FinalReportView inject `.environmentObject(viewModel)`; **không** host sheet nữa
- [`FinalReport/FinalReportView.swift`](FinalReport/FinalReportView.swift) — `@EnvironmentObject InspectionDetailViewModel`; `isUploading = activeUploadCount > 0` (display count = `totalUploadingImageCount`); `.onChange(activeUploadCount)` auto-send sau Firestore write; **hosts** `.sheet(isPresented: $inspectionDetailVM.showUploadStatusSheet)` — sheet phải present từ trong `fullScreenCover` context để tránh dismiss conflict
- [`InspectionDetailContentView.swift`](InspectionDetailContentView.swift) — "Hoàn tất" là simple button, không còn `hasActiveUploads`/`onShowUploadStatus`
- [`InspectionValidation/InspectionValidationView.swift`](InspectionValidation/InspectionValidationView.swift) — 3 init params: `onImageProgress`, `onImageDone`, `onImageFail`
- [`InspectionValidation/InspectionValidationViewModel.swift`](InspectionValidation/InspectionValidationViewModel.swift) — stores và gọi 3 `@Sendable` callbacks từ trong `TaskGroup`

### Domain — New Files
- [`ImageUploadItem.swift`](../../../Domain/Entities/ImageUploadItem.swift)
  - `enum ImageUploadStatus: Equatable` — `.pending`, `.uploading(progress: Double)`, `.done`, `.failed`
  - `struct ImageUploadItem: Identifiable` — `id`, `imageIndex`, `thumbnail: UIImage?`, `status: ImageUploadStatus`
  - `struct FieldUploadSession: Identifiable` — `id` (fieldId), `fieldLabel`, `items: [ImageUploadItem]`, `var isComplete: Bool`

### Domain — Modified Files
- [`UploadInspectionMediaUseCase.swift`](../../../Domain/UseCases/UploadInspectionMediaUseCase.swift)
  - `func executeWithProgress(imageData:inspectionId:onProgress: @Sendable @escaping (Double) -> Void) async throws -> String`

### Data — Modified Files
- [`FirebaseStorageService.swift`](../../../Data/Services/FirebaseStorageService.swift)
  - `func uploadImageWithProgress(_:path:onProgress: @Sendable @escaping (Double) -> Void) async throws -> String` — dùng `withCheckedThrowingContinuation` + `putData` + `task.observe(.progress)`
- [`StorageRepositoryType.swift`](../../../Domain/Repositories/StorageRepositoryType.swift) — thêm protocol method `uploadImageWithProgress`
- [`FirebaseStorageRepository.swift`](../../../Data/Repositories/FirebaseStorageRepository.swift) — implement method mới, forward sang `FirebaseStorageService`

---

## API Contracts

Không có API endpoint mới — feature giao tiếp trực tiếp với **Firebase Storage SDK**.

| Operation | Firebase API | Notes |
|-----------|-------------|-------|
| Upload với progress | `StorageReference.putData(_:metadata:completion:)` | Callback-based, không phải async/await |
| Observe progress | `StorageUploadTask.observe(.progress) { snapshot }` | `snapshot.progress?.fractionCompleted` |
| Get download URL | `StorageReference.downloadURL()` | async/await |

---

## Edge Cases & Error Handling

| Scenario | Expected Behavior | Handled? |
|----------|-----------------|----------|
| Ảnh upload thất bại | `failCb(index)` → `status = .failed` → ❌ "Thất bại" | ✅ |
| User tap "Hoàn tất" khi đang upload | `showFinalReport = true` ngay lập tức — navigate thẳng vào FinalReport, upload tiếp tục chạy nền | ✅ |
| Field chỉ có remote images (không có local) | `startUploadSession` early return nếu `localImages.isEmpty` | ✅ |
| User dismiss FinalReport | `@State showFinalReport` in `InspectionDetailView` set `false` when `FinalReportView` is dismissed | ✅ |
| `imageData` resize thất bại (`prepareForUpload()` trả nil) | `failCb(index)` được gọi | ✅ |
| Nhiều field upload đồng thời | Mỗi field là một `FieldUploadSession` riêng biệt | ✅ |
| Session cleanup | Xóa sessions đã complete khi `activeUploadCount == 0` | ✅ |
| Retry thất bại | Không hỗ trợ — intentional design decision | ✅ (by design) |
| **OOM crash khi nhiều ảnh 12MP** | Throttle `withTaskGroup` xuống max 4 concurrent — xem § Bugs Fixed | ✅ |
| **Upload chậm do file size lớn** | Giảm `maxDimension` 2048→1600px, file nhỏ hơn ~35–40% — xem § Bugs Fixed | ✅ |
| **Concurrent field upload ghi đè nhau** | `updateFieldImageURLs` serializes writes qua `pendingFieldWrite` task chain — xem § Bugs Fixed (B7) | ✅ |

---

## Bugs Fixed

### B1 — OOM Crash: `EXC_RESOURCE RESOURCE_TYPE_MEMORY` (limit exceeded 3072 MB)

**Ngày fix:** 2026-06-06  
**File:** [`InspectionValidation/InspectionValidationViewModel.swift`](InspectionValidation/InspectionValidationViewModel.swift) — `uploadPhotosAndUpdateField()`

**Root cause:**  
`withTaskGroup` gọi `group.addTask` cho **tất cả** ảnh cùng lúc. Mỗi `prepareForUpload()` cần ~100MB peak memory (original pixel buffer + `UIGraphicsImageRenderer` buffer + JPEG data). Với 10+ ảnh 12MP đồng thời → memory spike vượt giới hạn 3GB → crash.

**Fix:**  
Throttle TaskGroup xuống tối đa `maxConcurrent = 4` bằng cách seed 4 task đầu tiên, sau đó mỗi khi một task kết thúc mới enqueue task tiếp theo từ queue.

```swift
// Trước (unbounded — tất cả ảnh cùng lúc):
for (index, inspectionImage) in localImages.enumerated() {
    group.addTask { ... }
}

// Sau (throttled — tối đa 4 đồng thời):
let maxConcurrent = 4
// Seed 4 task đầu, sau đó for await { enqueue next }
```

---

### B3 — Upload chậm do file size lớn

**Ngày fix:** 2026-06-06  
**File:** [`../../Common/Helpers/UIImage+Upload.swift`](../../../Common/Helpers/UIImage+Upload.swift)

**Root cause:**  
`maxDimension` mặc định là 2048px. Ảnh 12MP resize về 2048×1536 + JPEG 0.8 quality cho ra file ~1–1.5MB/ảnh. Với 10 ảnh → ~12MB cần upload, bottleneck hoàn toàn từ network.

**Phân tích trade-off:**

| Setting | File size | Upload (4G ~5Mbps up) | PDF quality |
|---|---|---|---|
| 2048px @ 0.8 (cũ) | ~1–1.5MB | ~2–3s/ảnh | Không cải thiện so với 1600 trên A4 |
| **1600px @ 0.8 (mới)** | ~600KB–1MB | ~1–2s/ảnh | Không phân biệt được trên PDF A4 |
| 2048px @ 0.65 | ~600KB–900KB | ~1–2s/ảnh | Artifact JPEG rõ ở defect close-up |

Giảm `compressionQuality` (0.65) bị loại vì gây artifact JPEG trên ảnh kiểm tra defect. Giảm `maxDimension` (1600px) an toàn hơn vì 1600px trên A4 PDF (595pt wide) vẫn đủ ~2.7× DPI — không nhận ra bằng mắt.

**Fix:**

```swift
// Trước:
func prepareForUpload(maxDimension: CGFloat = 2048, compressionQuality: CGFloat = 0.8) -> Data?

// Sau:
func prepareForUpload(maxDimension: CGFloat = 1600, compressionQuality: CGFloat = 0.8) -> Data?
```

**Lợi ích thêm:** Renderer buffer nhỏ hơn ~30% → giảm peak memory trong `prepareForUpload`, hỗ trợ thêm cho B1 OOM fix.

---

### B4 — UploadStatusBottomSheet dismiss FinalReportView khi present

**Ngày fix:** 2026-06-08
**File:** [`FinalReport/FinalReportView.swift`](FinalReport/FinalReportView.swift), [`InspectionDetailView.swift`](InspectionDetailView.swift)

**Root cause:**
`.sheet(showUploadStatusSheet)` được attach vào `InspectionDetailView`. Khi `FinalReportView` (presented qua `fullScreenCover`) trigger `showUploadStatusSheet = true`, SwiftUI cố present sheet từ `InspectionDetailView` → dismiss `fullScreenCover` (FinalReportView) để giải phóng hierarchy.

```
BEFORE (broken):
InspectionDetailView
  ├── .sheet(showUploadStatusSheet)      ← parent owns sheet
  └── .fullScreenCover(showFinalReport)
        └── FinalReportView
              └── showUploadStatusSheet = true
                    → SwiftUI dismiss fullScreenCover ❌
```

**Fix:** Move `.sheet(showUploadStatusSheet)` từ `InspectionDetailView` sang `FinalReportView`. Sheet phải present từ cùng context với view trigger nó.

```
AFTER (fixed):
InspectionDetailView
  └── .fullScreenCover(showFinalReport)
        └── FinalReportView
              ├── .sheet(showUploadStatusSheet)   ← same context ✅
              └── showUploadStatusSheet = true → sheet present tại chỗ ✅
```

**Rule to remember:**
> `.sheet` phải được attach vào view **cùng level hoặc là ancestor trực tiếp** của view trigger nó. Khi view presenter là `fullScreenCover` hay `sheet`, sheet con phải được attach vào chính view đó — không phải parent bên ngoài.

---

### B5 — PDF không có ảnh: auto-send email trước khi Firestore update

**Ngày fix:** 2026-06-09
**File:** [`FinalReport/FinalReportView.swift`](FinalReport/FinalReportView.swift) — `actionButtonsSection`

**Root cause:**
`onChange(of: totalUploadingImageCount)` trigger `sendReport()` ngay khi tất cả ảnh upload xong (per-image `doneCb`). Nhưng `imageURLs` chỉ được write vào Firestore SAU KHI toàn bộ TaskGroup hoàn tất — tức là sau `storageService.updateInspection()` ở cuối `uploadPhotosAndUpdateField`. Kết quả: Cloud Function `processReportQueue` đọc Firestore khi `field.imageURLs = []` → PDF không có ảnh.

```
[Upload] image N → doneCb(N) → totalUploadingImageCount = 0
[onChange] fires → sendReport() → report_delivery_queue created
[CF] reads inspections/{id} → field.imageURLs = [] ← stale ❌
     ↓ (quá trễ)
[iOS] storageService.updateInspection → imageURLs = ["gs://..."] ✅
```

**Fix:** Đổi từ watch `totalUploadingImageCount` sang `activeUploadCount`. `activeUploadCount` về 0 chỉ sau `onTaskCompleted` → `notifyUploadCompleted()` — fires SAU `uploadPhotosAndUpdateField` (gồm cả Firestore update). Đồng thời đổi `isUploading` sang dùng `activeUploadCount > 0` để block button trong window ngắn giữa "ảnh upload xong" và "Firestore write xong".

```swift
// Trước (trigger sai):
let isUploading = inspectionDetailVM.totalUploadingImageCount > 0
.onChange(of: inspectionDetailVM.totalUploadingImageCount) { ... }

// Sau (trigger đúng — sau Firestore update):
let isUploading = inspectionDetailVM.activeUploadCount > 0
.onChange(of: inspectionDetailVM.activeUploadCount) { ... }
```

**Rule to remember:**
> Khi auto-trigger action phụ thuộc vào data đã được write vào Firestore, phải dùng signal fires SAU write — không dùng signal fires SAU network upload.

---

### B6 — markInspectionCompleted ghi đè imageURLs = [] (stale snapshot)

**Ngày fix:** 2026-06-09
**File:** [`FinalReport/FinalReportViewModel.swift`](FinalReport/FinalReportViewModel.swift) — `markInspectionCompleted()`

**Root cause:**
`FinalReportViewModel.inspection` là Swift `struct` value-type snapshot từ khi view được init — trước khi upload chạy. `markInspectionCompleted()` gọi `storageService.updateInspection(self.inspection)`, ghi đè Firestore với `imageURLs = []`. Cloud Function `processReportQueue` được trigger bởi `report_delivery_queue` doc ngay trước đó → đọc Firestore → thấy `imageURLs = []` → PDF không có ảnh.

```
Timeline:
[iOS] queueDeliveryUseCase.execute()   → report_delivery_queue doc created → CF wakes up
[CF]  reads inspections/{id}            ← imageURLs = ["gs://..."] (có thể kịp đọc đúng)
[iOS] markInspectionCompleted()         → updateInspection(stale self.inspection)
      → Firestore imageURLs = []        ← nếu CF chưa đọc xong → PDF không có ảnh ❌
```

**Fix:** Đọc fresh từ `storageService.getInspection(by: id)` — singleton cache đã được `uploadPhotosAndUpdateField` update với đúng URLs.

```swift
// Trước (BUG):
guard var updated = inspection else { return }  // stale snapshot, imageURLs = []

// Sau (FIXED):
guard let id = inspection?.id,
      var updated = storageService.getInspection(by: id) else { return }  // fresh từ cache
```

**Rule to remember:**
> Không dùng `self.inspection` (struct snapshot) khi gọi `storageService.updateInspection()` sau một upload flow. Luôn đọc fresh từ `storageService.getInspection(by: id)` để có đủ data đã được upload update vào cache.

---

### B7 — Concurrent field upload ghi đè nhau (last-writer-wins data loss)

**Ngày fix:** 2026-06-09
**Files:**
- [`../../Domain/Repositories/InspectionStorageServiceType.swift`](../../../Domain/Repositories/InspectionStorageServiceType.swift) — thêm `updateFieldImageURLs` vào protocol
- [`../../Data/Services/FirestoreInspectionStorageService.swift`](../../../Data/Services/FirestoreInspectionStorageService.swift) — serial write gate
- [`InspectionValidation/InspectionValidationViewModel.swift`](InspectionValidation/InspectionValidationViewModel.swift) — gọi method mới

**Root cause:**
Khi user kiểm tra Field A, navigate back, rồi kiểm tra Field B — cả hai upload chạy song song (mỗi cái là một Task riêng trong `saveValidation`). Cả hai đều gọi `storageService.updateInspection(inspection)` — là `setData` (full document replace). Cả hai đọc cùng một snapshot từ cache trước khi write nào hoàn tất, rồi write back với chỉ field của mình:

```
[t=1] Field A reads cache: { field_A.imageURLs: [],  field_B.imageURLs: [] }
[t=1] Field B reads cache: { field_A.imageURLs: [],  field_B.imageURLs: [] }
[t=2] Field A writes:      { field_A: ["url_A1"],   field_B: [] }        ✅
[t=3] Field B writes:      { field_A: [],            field_B: ["url_B1"] } ← OVERWRITES field A ❌
```

**Fix:** Thêm method `updateFieldImageURLs(inspectionId:fieldId:imageURLs:)` vào protocol và service. `FirestoreInspectionStorageService` giữ `@MainActor private var pendingFieldWrite: Task<Void, Error>?` — mỗi write mới chains lên task trước, đọc cache fresh SAU KHI write trước landing:

```swift
// FirestoreInspectionStorageService.swift
@MainActor private var pendingFieldWrite: Task<Void, Error>?

@MainActor
func updateFieldImageURLs(inspectionId: String, fieldId: String, imageURLs: [String]) async throws {
    let previous = pendingFieldWrite
    let newTask = Task { @MainActor in
        _ = try? await previous?.value          // chờ write trước xong
        guard var inspection = self.getInspection(by: inspectionId) else { return }
        // ...update only this field...
        try await self.updateInspection(inspection)
    }
    pendingFieldWrite = newTask
    try await newTask.value
}
```

`@MainActor` trên method + property đảm bảo read/write của `pendingFieldWrite` là atomic. Khi Field A suspend (`await taskA.value`), Field B có thể chạy trên main actor và thấy `pendingFieldWrite = taskA` — tạo `taskB` chains lên `taskA`. Kết quả:

```
[t=1] Field A: previous=nil, tạo taskA, pendingFieldWrite=taskA, await taskA.value → suspend
[t=2] Field B: previous=taskA, tạo taskB (awaits taskA), pendingFieldWrite=taskB, await taskB.value → suspend
[t=3] taskA: await nil → reads cache → writes field_A: ["url_A1"] ✅
[t=4] taskB: await taskA → reads FRESH cache → writes { field_A: ["url_A1"], field_B: ["url_B1"] } ✅
```

`InspectionValidationViewModel.uploadPhotosAndUpdateField` xóa bỏ manual read-modify-write block (cũng xóa luôn 2 `print()` statements), thay bằng:
```swift
try await storageService.updateFieldImageURLs(
    inspectionId: inspectionId, fieldId: fieldId, imageURLs: uploadedURLs
)
```

**Rule to remember:**
> Khi nhiều actors có thể write cùng một Firestore document, không dùng read-modify-write với `setData`. Serialize writes qua một `@MainActor Task` chain — mỗi write đọc fresh cache SAU KHI write trước landing. Nếu cần multi-client safety, dùng Firestore transaction.

---

### B2 — Button "Đóng" bị che khi scroll

**Ngày fix:** 2026-06-06  
**File:** [`UploadStatusBottomSheet.swift`](UploadStatusBottomSheet.swift)

**Root cause:**  
Trong sheet context, navigation bar của `NavigationStack` mặc định có background trong suốt (transparent). Khi user scroll, các card ScrollView render trên navigation bar, che khuất button "Đóng".

**Fix:**  
Thêm 2 modifier vào `NavigationStack` body:

```swift
.toolbarBackground(Color(.systemGroupedBackground), for: .navigationBar)
.toolbarBackground(.visible, for: .navigationBar)
```

`toolbarBackground(.visible)` force nav bar luôn opaque khi scroll — "Đóng" không bao giờ bị nội dung phía sau che nữa.

---

## Test Coverage Notes

| Component | Test File | Coverage |
|-----------|-----------|----------|
| `UploadStatusBottomSheet` | — | ❌ Missing |
| `ImageUploadItem` / `FieldUploadSession` | — | ❌ Missing |
| `InspectionDetailViewModel` upload tracking | — | ❌ Missing |
| `UploadInspectionMediaUseCase.executeWithProgress` | — | ❌ Missing |
| `FirebaseStorageService.uploadImageWithProgress` | — | ❌ Missing |

**Suggested test cases:**
- [ ] `startUploadSession` với 0 local images → không tạo session, `activeUploadCount` không tăng
- [ ] `notifyUploadCompleted` khi `activeUploadCount = 1` và `pendingEmailSend = true` → `pendingEmailSend` reset về `false` + `sendReport()` được gọi
- [ ] `totalUploadingImageCount` chỉ đếm `.pending` và `.uploading` — không đếm `.done`, `.failed`
- [ ] `FieldUploadSession.isComplete` trả `true` khi tất cả items là `.done` hoặc `.failed`
- [ ] `makeUploadCallbacks(for:)` callbacks dispatch đúng lên `@MainActor`

---

## Notes

- **`@Sendable` requirement:** Callbacks phải `@Sendable` vì `withTaskGroup` trong `uploadPhotosAndUpdateField` chạy trên non-isolated context. Các callbacks được capture như local variables trước khi vào TaskGroup để tránh truy cập `self` (MainActor) từ Sendable closure.
- **`withCheckedThrowingContinuation` trong `actor`:** `FirebaseStorageService` là `actor`; continuation và `observe(.progress)` callback chạy trên Firebase's internal thread — safe vì không access actor state bên trong callback.
- **`presentationDetents([.medium, .large])`:** User có thể kéo bottom sheet lên full screen để xem toàn bộ danh sách.
- **Session không persist:** Nếu user force-quit app trong lúc upload, sessions mất — không có resume support.

---

*Generated by `/ct-ai-document` on 2026-06-06 — Last updated: 2026-06-09 (B5: activeUploadCount trigger; B6: markInspectionCompleted stale snapshot; B7: concurrent field upload race condition → updateFieldImageURLs serial write gate; BUG-F04: fixed stale shouldShowFinalReport reference in Edge Cases)*
