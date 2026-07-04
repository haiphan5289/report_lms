# Image Cache Workflow Documentation

## 📋 Tổng quan

Tài liệu này mô tả kiến trúc, luồng dữ liệu và memory budget của hệ thống cache ảnh trong `InspectionValidationView` và `InspectionDetailView`.

Hệ thống gồm **2 RAM cache actor** + **1 upload coordinator/field** phục vụ 4 loại ảnh khác nhau:

| Loại ảnh | Nguồn | Hiển thị | Nơi khởi tạo |
|---|---|---|---|
| **Capture (màn hình validation)** | Camera (UIImage 12MP) | `images[].thumbnail` (800px) | `InspectionValidationView` → `appendImages` |
| **Capture (chụp nhanh field-list)** | Camera (UIImage 12MP) | `images[].thumbnail` (800px) | `InspectionDetailView` → `handleQuickCapture` |
| **Remote** | Firebase Storage URL | `InspectionCachedImage` → 3-tier lookup | — |
| **Edit download** | Firebase Storage URL | `downloadImage(from:)` → `ImageCacheActor` | `InspectionValidationViewModel` |

**Quan trọng:** kể từ khi `FieldUploadCoordinator.commitCapturedPhotos` ra đời, **cả 2 luồng capture đều đi qua đúng 1 pipeline** — không còn đường riêng nào chỉ tồn tại trong RAM. Xem § [Kiến trúc capture-time durability](#-kiến-trúc-capture-time-durability).

---

## 🗂️ Cấu trúc file

```
Sources/
├── Common/
│   ├── Helpers/
│   │   ├── InspectionImageCacheActor.swift   # Cache durable cho ảnh inspection (Documents/)
│   │   ├── ImageCacheActor.swift              # Cache chung cho remote images (Caches/)
│   │   ├── PendingUploadStore.swift           # Tracks file paths chờ upload (UserDefaults)
│   │   └── PendingUploadRetryService.swift    # Retry upload khi app restart (global, 1 lần)
│   └── Components/
│       └── CachedAsyncImage.swift             # AsyncImage + ImageCacheActor (dùng chung)
├── Presentation/Modules/Camera/
│   ├── CameraViewModel.swift                  # capturePhoto() ghi disk NGAY; struct CapturedPhoto
│   └── CameraView.swift                       # 2 init: legacy [UIImage] / rich [CapturedPhoto]
├── Domain/Entities/
│   └── FieldValidation.swift                  # InspectionImage struct
└── Presentation/Modules/InspectionDetail/
    ├── FieldUploadCoordinator.swift           # Long-lived/field — SOURCE OF TRUTH duy nhất
    ├── InspectionDetailViewModel.swift         # handleQuickCapture, restoreLocalPendingPhotos
    └── InspectionValidation/
        ├── InspectionValidationViewModel.swift # appendImages, loadPendingCaptures, saveValidation
        └── Views/
            └── InspectionCachedImage.swift     # 3-tier loader cho remote images
```

---

## 🏗️ Kiến trúc hai cache actor

```
┌─────────────────────────────────────────────────────────────────────┐
│                    InspectionImageCacheActor                         │
│  Durable — Documents/inspection-images/<id>/<field>/  (iOS KHÔNG purge) │
│  RAM: max 60 entries, FIFO evict 30                                  │
│  Key: absolute file path                                             │
│                                                                      │
│  commitPendingCapture(from:thumbnail:inspectionId:fieldId:)          │
│  ├── Move pending_<uuid>.jpg → capture_<uuid>.jpg (RENAME, KHÔNG encode lại) │
│  └── RAM: thumbnail 800px (do caller truyền vào, đã resize từ trước) │
│                                                                      │
│  recoverOrphanedPendingCaptures(inspectionId:fieldId:) → [String]    │
│  └── Quét pending_*.jpg mồ côi (app bị kill trước khi commit xong)   │
│      → decode, resize 800px, gọi commitPendingCapture cho từng file  │
│                                                                      │
│  cacheRemote(image:url:inspectionId:fieldId:)                        │
│  ├── RAM: resized 1024px (~4MB)                                      │
│  └── Disk: Documents/inspection-images/<id>/<field>/remote_<sha>.jpg │
│                                                                      │
│  loadFromPath(path) → UIImage?      (display retry)                  │
│  loadRemote(url:...) → UIImage?     (display remote)                 │
│  evictInspection(id)                (delete/complete)                │
│  evictAllRAM()                      (memory warning)                 │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                         ImageCacheActor                              │
│  Ephemeral — Caches/ (iOS có thể purge)                              │
│  RAM: max 100 entries, FIFO evict 50                                 │
│  Key: stable URL (query params stripped)                             │
│                                                                      │
│  image(for: URL) → UIImage?         (read)                           │
│  store(_ image: UIImage, for: URL)  (write)                          │
│  clearAll()                         (manual evict)                   │
└─────────────────────────────────────────────────────────────────────┘
```

`cacheCapture(image:thumbnail:inspectionId:fieldId:)` (encode + write trực tiếp từ `UIImage`) vẫn còn trong `InspectionImageCacheActor` nhưng **không còn caller nào** — mọi capture giờ đi qua `commitPendingCapture` (move file có sẵn, không encode lại).

---

## 🔒 Kiến trúc capture-time durability

Vấn đề gốc: trước đây, ảnh chụp chỉ tồn tại trong RAM (`UIImage`) từ lúc bấm chụp cho tới khi Phase 2 ghi xong JPEG xuống disk — nếu app bị kill/crash trong khoảng đó, ảnh mất vĩnh viễn, không cách nào phục hồi.

**Giải pháp — ghi disk ngay tại thời điểm bấm chụp, trước khi user kịp thấy ảnh trong preview:**

```
CameraController.capturePhoto (AVFoundation callback)
      │
      ▼
CameraViewModel.persistCapture(image:)   [private, gọi từ capturePhoto()]
      │
      ├── writePendingFile(image:id:in:)   (Task.detached .userInitiated)
      │   └── JPEG 0.85 → <pendingCapturesDir>/pending_<uuid>.jpg
      │       ├── Có inspectionId+fieldId (rich init)
      │       │     → Documents/inspection-images/<id>/<field>/   ← DÙNG CHUNG dir với InspectionImageCacheActor
      │       └── Không có (legacy init — errorReport/general)
      │             → Documents/pending-captures/   (scratch, xoá ngay sau handoff)
      │
      └── capturedImages.append(CapturedPhoto(id:image:fileURL:))
              ↑ image = full-res UIImage (chỉ để hiển thị preview trong camera)
              ↑ fileURL = đường dẫn file JPEG ĐÃ AN TOÀN trên disk
```

- **Xoá ảnh trong lúc xem preview** (`CameraViewModel.deleteImage(at:)`) → xoá luôn file `pending_*.jpg` tương ứng, không rác.
- **Bấm "Done"** → `CameraView` gọi `viewModel.finishedHandoff(keepFiles:)`:
  - `keepFiles: true` (rich init — inspection flow) → giữ file, giao `[CapturedPhoto]` cho caller tự commit.
  - `keepFiles: false` (legacy init) → xoá file ngay, vì caller chỉ cần `UIImage` trong RAM (không có safety-net, giữ đúng risk profile như trước khi có fix này).
- **Cancel / vuốt dismiss / huỷ permission alert** → `.onDisappear` luôn gọi `finishedHandoff(keepFiles: false)` — dọn sạch file còn sót, bất kể user thoát bằng cách nào.

**Commit (rename, không encode lại) — dùng chung cho cả 2 caller:**

```
FieldUploadCoordinator.commitCapturedPhotos(_ captured: [CapturedPhoto]) async
      │
      ├── Phase 1 — resize song song, tối đa 4 Task.detached đồng thời (.utility)
      │   ├── Mỗi ảnh: resizedIfNeeded(800px) → UIImage thumbnail
      │   └── InspectionImage(image: thumb) → appendImage(img)   [progressive — hiện ngay từng ảnh]
      │
      └── Phase 2 — với mỗi CapturedPhoto:
          ├── InspectionImageCacheActor.commitPendingCapture(from: photo.fileURL, thumbnail:...)
          │   └── FileManager.moveItem: pending_<uuid>.jpg → capture_<uuid>.jpg  (RENAME, tức thời)
          ├── PendingUploadStore.addPending(filePath:...)
          └── updateImageFileURL(id:fileURL:)
```

Vì Phase 2 chỉ *move* file (đã có sẵn, đã an toàn từ lúc chụp) — không encode lại — nên **không giữ `UIImage` full-res nào trong bộ nhớ ở Phase 2 cả**. Nếu app bị kill giữa Phase 2, ảnh chưa move xong vẫn còn nằm dạng `pending_*.jpg` → được `recoverOrphanedPendingCaptures` nhặt lại ở lần load field tiếp theo.

---

## 🔄 Workflow: Chụp ảnh mới trong màn hình Validation (`appendImages`)

```
User chụp ảnh trong CameraView (rich init, có inspectionId+fieldId)
      │  (ảnh ĐÃ ghi pending_<uuid>.jpg xuống disk từ lúc bấm chụp — xem mục trên)
      ▼
InspectionValidationView: CameraView(...) { photos in viewModel.appendImages(photos) }
      │
      ▼
appendImages([CapturedPhoto])   @MainActor
      │
      └── Task { @MainActor in
              await coordinator.commitCapturedPhotos(captured)   ← Phase 1 + Phase 2 (xem mục trên)
              │
              ├── status .pending → .passed (auto-advance)
              ├── updateDirtyState()
              └── saveValidation(status:, notifyParent: false)
                      └── coordinator.enqueue(status:, comments:)
                              └── currentTask = Task { [self] in   ← chained: await prevTask?.value trước
                                      → uploadPhotosAndUpdateField(originalImages:strippedImages:status:comments:)
                                      → updateInspectionStatus()    ← ghi status Firestore (.inProgress)
                                      → onTaskCompleted()           ← activeUploadCount-- trong InspectionDetailViewModel
                                  }
          }
```

**Ghi chú quan trọng — kiến trúc đã đổi so với trước:**
- `currentTask`/`enqueue` nằm trên **`FieldUploadCoordinator`**, không phải `InspectionValidationViewModel`. Coordinator sống lâu hơn view (owned by `InspectionDetailViewModel`), nên `Task { [self] in ...}` dùng **strong capture (`[self]`) có chủ đích** — chính là để sửa bug cũ: nếu dùng `[weak self]` và user dismiss `InspectionValidationView` trước khi upload xong, task sẽ bị drop giữa đường.
- `saveValidation` không tự tay build `imagesForUpload` — nó gọi `coordinator.enqueue(status:comments:)`, và chính `enqueue` mới tự strip thumbnail (`strippedThumbnails(from:)`) trước khi truyền vào `uploadPhotosAndUpdateField`.

---

## 🔄 Workflow: "Chụp nhanh" từ field-list (`handleQuickCapture`)

Icon camera cạnh mỗi field trên `InspectionDetailView` (không cần mở hẳn `InspectionValidationView`) — dùng **đúng pipeline trên**, không có đường riêng:

```
User bấm icon camera trên field-list
      │
      ▼
InspectionDetailViewModel.openCamera(for: fieldId)
      │   selectedFieldId = fieldId; showCamera = true
      ▼
CameraView(source: .inspection, inspectionId:, fieldId:) { photos in viewModel.handleQuickCapture(photos) }
      │  (ảnh ĐÃ ghi pending_<uuid>.jpg xuống disk từ lúc bấm chụp)
      ▼
handleQuickCapture([CapturedPhoto])   @MainActor
      │
      ├── guard let fieldId = selectedFieldId   ← KHÔNG tự xoá selectedFieldId ở đây
      │     (chỉ fullScreenCover's onDismiss mới xoá — tránh invalidate `if let` đang hiển thị camera)
      ├── coordinator = makeCoordinator(for: fieldId)
      │
      └── Task { @MainActor in
              await coordinator.commitCapturedPhotos(captured)   ← CÙNG hàm với appendImages
              │
              ├── handleValidationUpdate(FieldValidation(status: .passed, images: coordinator.images, ...))
              │     └── capturedPhotos[fieldId] = ...   (echo tức thời để field-list hiện ảnh ngay)
              │
              └── coordinator.enqueue(status: .passed, comments: "")   ← tự upload NGAY, không cần user
          }                                                             bấm "Đạt"/"Không áp dụng"
```

**Vì sao route qua `coordinator` thay vì lưu riêng vào `capturedPhotos`:** trước đây `handlePhotoSelection`/`savePhoto` lưu `InspectionImage(image: image)` (full-res, không resize, không `fileURL`) thẳng vào `capturedPhotos[fieldId]` — một RAM store hoàn toàn tách biệt với `coordinator.images`. Hậu quả: mất ảnh khi kill app, không tự upload (phải mở validation screen + bấm "Đạt" mới enqueue), 2 nguồn sự thật lệch nhau khi mở validation screen 2 lần, giữ ảnh 12MP dài hạn trong RAM, và **`submitInspection()` có thể âm thầm bỏ sót ảnh chưa `.isRemote`** nếu user nộp báo cáo trước khi tự đi mở field đó ra. Route qua `coordinator.commitCapturedPhotos` + `coordinator.enqueue` giải quyết toàn bộ cùng lúc.

---

## 🔄 Workflow: Hiển thị ảnh remote (`InspectionCachedImage`)

```
InspectionCachedImage(url:inspectionId:fieldId:)
      │
      ├── Step 1: InspectionImageCacheActor.loadRemote(url:...)
      │   ├── RAM hit  → return 1024px UIImage  ✅ instant
      │   └── Disk hit → resize 1024px + preparingForDisplay → addToRAM → return
      │
      ├── Step 2: ImageCacheActor.image(for: url)
      │   ├── RAM hit  → return UIImage  ✅ fast
      │   └── miss → continue
      │       └── Promote: Task.detached { cacheRemote(...) }  [background, deduplicated]
      │
      └── Step 3: URLSession.data(from: url)  (network)
          ├── Decode + preparingForDisplay (Task.detached)
          ├── Task.detached (background):
          │   ├── ImageCacheActor.store(img, for: url)
          │   └── InspectionImageCacheActor.cacheRemote(img, url:...)
          │       ├── RAM: resize 1024px + preparingForDisplay
          │       └── Disk: Documents/.../remote_<sha256>.jpg
          └── phase = .success(Image(uiImage: img))
```

*(Không đổi so với trước — không phụ thuộc kiến trúc capture.)*

---

## 🔄 Workflow: Mở field, phục hồi ảnh pending (`loadPendingCaptures`)

```
InspectionValidationView.task { await viewModel.loadPendingCaptures() }   ← KHÔNG phải .onAppear
      │
      ▼
loadPendingCaptures()
      │
      ├── InspectionImageCacheActor.recoverOrphanedPendingCaptures(inspectionId:fieldId:)
      │   └── Quét pending_*.jpg mồ côi (app bị kill lúc camera sheet còn mở, trước khi
      │       commitCapturedPhotos chạy) → commit từng file → trả về danh sách path
      │       → addPending() cho từng path recovered (chưa từng có entry trong PendingUploadStore)
      │
      ├── PendingUploadStore.getPendingFilePaths(inspectionId, fieldId)
      │   └── filter: FileManager.fileExists(atPath:)  (loại bỏ stale paths)
      │
      ├── [nếu chưa có local images trong coordinator.images]
      │   └── InspectionImageCacheActor.loadFromPath(path) × N
      │       ├── RAM hit  → thumbnail 800px  ✅
      │       └── RAM miss → đọc full-res JPEG từ disk → resize 800px + preparingForDisplay → addToRAM
      │
      ├── coordinator.prependImages(loadedImages)
      ├── onSilentSave?(retryValidation)  → InspectionDetailViewModel.handleValidationUpdate
      │       (set capturedPhotos[fieldId] + startUploadSession — hiện badge upload)
      └── await coordinator.retry(status:, comments:)   ← trigger upload thật
```

---

## 🔄 Workflow: Phục hồi field-list sau cold-launch (`InspectionDetailViewModel.loadInspectionDetail`)

```
InspectionDetailView.task { await viewModel.loadInspectionDetail() }
      │
      ▼
loadInspectionDetail()
      │
      ├── storageService.getInspection(by: inspectionId)  → inspection
      │
      ├── restoreCapturedPhotos(from:)
      │   └── Chỉ đọc field.imageURLs (Firestore) — ảnh ĐÃ upload xong hoàn toàn
      │
      ├── await restoreLocalPendingPhotos()          ← AWAIT trước khi isLoading = false
      │   └── PendingUploadStore.getAllPendingFields(for: inspectionId)
      │       └── mỗi field: InspectionImageCacheActor.loadFromPath(path) × N  (đọc disk, KHÔNG cần mạng)
      │           → capturedPhotos[fieldId] = loadedImages + existing
      │
      ├── isLoading = false     ← render lần đầu ĐÃ có đủ dữ liệu (remote + local-pending)
      ├── contentViewModel.autoExpandFirstSection()
      │
      └── startNetworkMonitoring()
              └── khi network restore sau khi offline → retryAllPendingUploads()
                    (đọc PendingUploadStore, tạo InspectionValidationViewModel tạm, loadPendingCaptures())
```

**Quan trọng:** `retryAllPendingUploads()` **không còn được gọi lúc `loadInspectionDetail()`** (khác với `PendingUploadRetryService`, chạy global 1 lần lúc app launch trong `report_lmsApp.init()`). Gọi cả 2 nơi cùng lúc từng gây race: cả 2 cùng thấy 1 `PendingUploadStore` entry, cùng tự upload độc lập → `UploadInspectionMediaUseCase.execute` sinh UUID path mới mỗi lần gọi (không dedupe) → nguy cơ **upload trùng ảnh lên Storage**. Giờ chỉ còn dùng cho case network-restore, thời điểm đó launch-time global retry chắc chắn đã settle từ lâu.

---

## 🔄 Workflow: Upload (`FieldUploadCoordinator.enqueue` → `uploadPhotosAndUpdateField`)

```
coordinator.enqueue(status:comments:)   @MainActor
      │
      └── currentTask = Task { [self] in   ← strong capture có chủ đích (coordinator sống lâu hơn view)
              _ = await prevTask?.value    ← chained
              let stripped = strippedThumbnails(from: images)
              await uploadPhotosAndUpdateField(originalImages: images, strippedImages: stripped, status:, comments:)
              await updateInspectionStatus()
              onTaskCompleted?()
          }

uploadPhotosAndUpdateField(originalImages:strippedImages:status:comments:)
      │
      ├── existingRemoteURLs = strippedImages.compactMap { isRemote ? remoteURL?.absoluteString : nil }   ← [String]
      ├── fullIndexedLocal = strippedImages.enumerated().filter { !isRemote }
      │
      └── withTaskGroup(...)   ← quản lý concurrency thủ công qua nextIndex/addJob
          │   ┌─────────────────────────────────────────────────┐
          │   │ maxConcurrentSlots:                              │
          │   │  <6 GB          → 3  (mọi mạng)                 │
          │   │  6–8 GB, WiFi   → 5  / Cellular → 4             │
          │   │  ≥8 GB, WiFi    → 6  / Cellular → 5             │
          │   └─────────────────────────────────────────────────┘
          ├── Mỗi slot: compress + upload pipeline (~56 MB peak/slot)
          │   ├── Task.detached: đọc fileURL (full-res) hoặc fallback thumbnail
          │   │   └── UIImage.prepareForUpload(1600px, quality:0.8) → Data
          │   │       (thử WebP trước trên iOS 14+, fallback JPEG — ~35% nhỏ hơn)
          │   └── UploadInspectionMediaUseCase.executeWithProgress(imageData:inspectionId:onProgress:)
          │       └── StorageRepository.uploadImageWithProgress(...) → FirebaseStorageService.uploadImageWithProgress(imageData:path:onProgress:)
          │           ├── withThrowingTaskGroup: race upload vs Task.sleep(90s)
          │           │   ├── Upload task: withTaskCancellationHandler {
          │           │   │       withCheckedThrowingContinuation { putData + observe(.progress) }
          │           │   │   } onCancel: { holder.task?.cancel() }   ← Firebase cancel → connection freed
          │           │   └── Timeout task: sleep(90s) → throw URLError(.timedOut)
          │           │       → tg.cancelAll() → onCancel fires → Firebase .cancel() → no zombie connection
          │           ├── onProgress → InspectionDetailViewModel.updateImageProgress (UI badge)
          │           ├── onDone    → markImageDone
          │           └── onFail    → markImageFailed (timeout cũng fail cleanly)
          │
          ├── for await (idx, urlString) in group   ← PROGRESSIVE RELEASE, on MainActor
          │   └── Với mỗi ảnh upload thành công ngay lập tức:
          │       ├── images[pos] = InspectionImage(remoteURL:, description:)   ← giữ description cũ
          │       │   └── giải phóng UIImage thumbnail ~2MB khỏi coordinator heap NGAY
          │       └── Task.detached(priority: .background) {
          │               InspectionImageCacheActor.cacheRemote(thumb, remoteURL, ...)
          │           }   ← pre-populate RAM hit cho lần display tiếp
          │
          ├── existingDescriptions + newDescriptions → uploadedDescriptions
          ├── storageService.updateFieldImageURLs(inspectionId:fieldId:imageURLs:imageDescriptions:)
          │   └── Serial write chain (pendingFieldWrite Task) — safe khi nhiều field đồng thời
          ├── PendingUploadStore.clearField(inspectionId:fieldId:)
          ├── onSilentSave?(updatedDraft)  ← propagate remote images lên InspectionDetailViewModel.capturedPhotos
          └── onUploadComplete?()
```

**Tại sao strip thumbnail trước khi truyền vào `uploadPhotosAndUpdateField`:**
Camera photos có `fileURL` → upload đọc từ disk, KHÔNG cần thumbnail. Nếu không strip: `images` parameter (value-type copy) giữ strong ref đến tất cả N UIImages trong suốt thời gian function chạy. Với 300 ảnh × 2MB = 600MB pinned cho đến khi function return → vượt jetsam threshold trên 4GB device.

**Tại sao timeout + cancellation nằm trong `FirebaseStorageService` (không phải coordinator):**
Timeout ở tầng gọi chỉ giải phóng slot, nhưng Firebase `StorageUploadTask` vẫn tiếp tục chạy ngầm — giữ URLSession connection. URLSession có max 6 connections/host. Sau N timeout, tất cả 6 connections bị chiếm bởi "zombie" tasks → upload mới không mở được connection → kẹt mãi ở "Đang chờ". Đặt cancel tại Firebase layer (`holder.task?.cancel()`) → Firebase gọi completion callback với lỗi cancelled → `withCheckedThrowingContinuation` resume → connection được đóng ngay.

**Ghi chú về persistence ảnh mô tả (description):** `existingDescriptions`/`newDescriptions` được gộp và ghi vào Firestore cùng lúc với `imageURLs`, qua tham số `imageDescriptions:` — đây là caption do inspector nhập, sống sót qua các lần upload nối tiếp.

---

## 🔄 Workflow: Retry tại app launch (`PendingUploadRetryService`)

```
App launch (report_lmsApp.init)
      │
      ▼
Task { await storageService.loadCache(); PendingUploadRetryService.shared.retryAllPendingUploads() }
      │
      ▼
PendingUploadRetryService.retryAllPendingUploads()   ← GLOBAL, chạy ĐÚNG 1 LẦN, quét TẤT CẢ inspection
      │
      ├── PendingUploadStore.getAllPendingInspectionIds()
      └── Mỗi (inspectionId, fieldId, paths):
          └── Task { uploadField(...) }
              │
              ├── Đọc full-res JPEG trực tiếp từ disk (KHÔNG qua RAM cache, KHÔNG qua FieldUploadCoordinator)
              │   └── Task.detached { Data(contentsOf: path) → UIImage(data:) }
              │
              ├── UIImage.prepareForUpload() → Data
              ├── uploadUseCase.execute(imageData:inspectionId:)
              ├── storageService.updateFieldImageURLs(...)
              └── PendingUploadStore.clearField(...)   ← chỉ khi thành công
```

**Đây là nguồn retry DUY NHẤT chạy tự động lúc app khởi động** — `InspectionDetailViewModel.retryAllPendingUploads()` (khác class, tên dễ nhầm) không còn được gọi ở `loadInspectionDetail()` nữa, chỉ còn dùng cho case network-restore trong lúc màn hình đang mở (xem workflow phía trên). Việc tách ra tránh 2 cơ chế cùng nhặt 1 `PendingUploadStore` entry và tự upload độc lập.

**Quan trọng:** `PendingUploadRetryService` đọc disk trực tiếp (không qua `loadFromPath`) để đảm bảo luôn upload full-res, bất kể RAM cache đang chứa thumbnail hay không. Nó **không notify UI nào cả** — `InspectionDetailViewModel.restoreLocalPendingPhotos()` (đọc disk riêng, độc lập) là cơ chế khiến field-list hiện đúng ảnh/count ngay từ frame render đầu tiên, không phụ thuộc việc service này upload xong lúc nào.

---

## 🔄 Workflow: Xóa inspection (`deleteInspection` cascade)

```
User xóa inspection
      │
      ▼
FirestoreInspectionStorageService.deleteInspection(by: id)
      │
      ├── 1. Đọc inspection từ cache  ← cần photoURLs trước khi doc bị xóa
      │
      ├── 2. [blocking] firestoreService.deleteInspection(id)   ← nếu lỗi → throw, UI rollback
      │
      ├── 3. [blocking] cache.removeAll { $0.id == id }
      │           + NotificationCenter.post(.inspectionDidUpdate)
      │
      ├── 4. Task.detached(priority: .background)   ← fire & forget
      │   ├── InspectionImageCacheActor.evictInspection(id)
      │   │   ├── RAM: xóa tất cả keys có prefix = inspDir.path
      │   │   └── Disk: removeItem(at: inspDir)   ← Documents/inspection-images/<id>/
      │   │       (dọn sạch CẢ capture_*.jpg VÀ pending_*.jpg mồ côi, cùng 1 dir)
      │   └── PendingUploadStore.clearInspection(id)
      │
      └── 5. Task { }   ← fire & forget, lỗi được logged (không silently dropped)
          ├── FirebaseStorageService.deleteFolder("inspections/\(id)")
          │   └── storage.reference().child(path).listAll()   ← bắt CẢ file orphan
          │       → xóa từng item, log lỗi nếu fail, tiếp tục (không dừng giữa chừng)
          ├── firestoreService.fetchErrorItemsForDeletion(inspectionId: id)
          │   └── Mỗi errorItem:
          │       ├── storageService.deleteImage(fromURL:) × N   ← log lỗi nếu fail
          │       ├── firestoreService.deleteErrorItem(...)       ← log lỗi nếu fail
          │       └── LocalImageStore.shared.clear(for: item.id)
          └── deliveryQueueService.deleteTasksForInspection(inspectionId: id)
```

**Tại sao dùng `deleteFolder` thay vì loop URL:**
- `field.imageURLs` chỉ chứa URL đã được ghi vào Firestore thành công.
- File bị orphan (upload thành công nhưng URL bị ghi đè do race condition cũ) không có trong danh sách → không bao giờ bị xóa nếu chỉ loop URL.
- `listAll()` liệt kê TẤT CẢ file dưới prefix path → xóa sạch, kể cả orphan.

---

## 💾 Memory Budget

### Kích thước ảnh trong RAM

| Loại | Kích thước RAM | Ghi chú |
|---|---|---|
| Capture thumbnail (800px) | ~2MB | `coordinator.images[].thumbnail` + `InspectionImageCacheActor.ram` (shared ref) |
| Remote display (1024px) | ~4MB | `InspectionImageCacheActor.ram` |
| Full-res 12MP decoded | ~48MB | Tồn tại tạm trong `CameraViewModel.capturedImages` (lúc còn ở màn camera) và trong pipeline upload/edit — không lưu RAM lâu dài |

### Giới hạn và eviction

| Cache | Max entries | Evict | Evictable bởi memory warning? |
|---|---|---|---|
| `InspectionImageCacheActor.ram` | 60 | FIFO 30 | ✅ `evictAllRAM()` |
| `ImageCacheActor.ram` | 100 | FIFO 50 | ❌ (tự FIFO) |
| `coordinator.images[].thumbnail` | Không giới hạn | Progressive trong `for await` upload loop; hoặc khi field bị evict | ✅ (sau mỗi upload) |
| `CameraViewModel.capturedImages[].image` | Bị chặn bởi `maxPhotos` (20 với `.inspection`) | Xoá ngay khi user xoá ảnh trong preview, hoặc `finishedHandoff` lúc Done/Cancel | N/A — sống rất ngắn (chỉ trong lúc màn camera mở) |

### Worst case (60 remote images trong `InspectionImageCacheActor`)

```
60 entries × 4MB = 240MB  (InspectionImageCacheActor.ram)
N captures × 2MB = ~20MB  (shared ref coordinator + actor)
ImageCacheActor.ram       = ~80-100MB (overlap với remote)
─────────────────────────────────────
Tổng peak realistic       ≈ 300-400MB
```

---

## 🔑 Thiết kế quan trọng

### 1. `remoteKey` dùng SHA256 (không dùng `hashValue`)

```swift
// ❌ Sai — hashValue thay đổi mỗi lần restart app (Swift seed randomisation)
return String(stable.hashValue & 0x7FFFFFFFFFFFFFFF, radix: 16)

// ✅ Đúng — SHA256 deterministic, stable across restarts
SHA256.hash(data: data).prefix(16).map { String(format: "%02x", $0) }.joined()
```

### 2. Upload dùng full-res, display dùng thumbnail

```
fileURL (disk) → upload   ← full-res JPEG, ~8MB/file
thumbnail (RAM) → display ← 800px UIImage, ~2MB
```

`PendingUploadRetryService` đọc disk trực tiếp, bỏ qua `loadFromPath` vì RAM có thể chứa thumbnail.

### 3. Ghi disk NGAY tại thời điểm chụp — không đợi đến Phase 2

`CameraViewModel.persistCapture` ghi `pending_<uuid>.jpg` xuống disk ngay khi AVFoundation trả về ảnh, trước khi user kịp bấm "Done". `FieldUploadCoordinator.commitCapturedPhotos` chỉ *move* file này — không encode lại lần nào cả trong toàn bộ pipeline capture → commit.

### 4. Một coordinator/field là NGUỒN SỰ THẬT DUY NHẤT

Cả `InspectionValidationViewModel.appendImages` (màn hình validation) và `InspectionDetailViewModel.handleQuickCapture` (icon camera field-list) đều mutate `coordinator.images` qua `commitCapturedPhotos` — không còn RAM store riêng nào khác giữ ảnh capture. `InspectionDetailViewModel.capturedPhotos` chỉ là **cache hiển thị**, đồng bộ qua callback `onSilentSave`/`handleValidationUpdate`, không phải nguồn sự thật.

### 5. `promotingKeys` deduplication trong `cacheRemote`

Nhiều `InspectionCachedImage` cell cùng URL → tất cả đều hit `ImageCacheActor` → tất cả launch `Task.detached { cacheRemote(...) }`. Actor serialize nhưng vẫn encode JPEG + ghi disk nhiều lần. `promotingKeys` guard ngăn redundant work.

---

## ⚠️ Giới hạn đã biết

| Vấn đề | Nguyên nhân | Trade-off chấp nhận được |
|---|---|---|
| `submitInspection()` không chờ `activeUploadCount` | Nộp báo cáo trong lúc ảnh vẫn đang upload (dù đã enqueue) → ảnh đó chưa `.isRemote` sẽ bị lọc bỏ khỏi `imageURLs` cuối, không cảnh báo | Xác suất thấp vì quick-capture giờ tự enqueue ngay lúc chụp, nhưng vẫn CHƯA được fix triệt để — cần gate `submitInspection()` trên `activeUploadCount == 0` |
| `ImageCacheActor` không resize | Dùng chung toàn app, resize có thể break edit flow | Tự FIFO evict tại 100 entries |
| Disk capture không xoá sau upload | `PendingUploadStore.clearField` clear tracking nhưng không xoá file `capture_*.jpg` | `evictInspection()` dọn khi delete/complete |
| `evictAllRAM()` log MB giải phóng thấp hơn thực tế | Log hardcode `count × 2 MB` — đúng với capture (800px) nhưng sai với remote (1024px = ~4MB/entry) | Chỉ ảnh hưởng con số trong log, không ảnh hưởng logic eviction |
| `replaceImage(at:with:)` upload chất lượng thấp hơn | Khi thay ảnh: tạo `InspectionImage` chỉ có thumbnail resize 800px (không có `fileURL`) → upload dùng 800px thay vì full-res JPEG | Ảnh chỉnh sửa hiếm gặp, chấp nhận được trong production |
| `isOnWiFiOrEthernet` block cooperative thread | Dùng `DispatchSemaphore.wait()` để lấy network snapshot — block thread trong ~vài ms | Chỉ gọi 1 lần mỗi upload batch, không gây ANR thực tế |
| Legacy camera flows (errorReport/general) không có safety-net disk | `CameraView` legacy init (`[UIImage]`) xoá `pending_*.jpg` ngay sau handoff — chỉ flow `.inspection` (rich init) mới giữ file lâu dài | Ngoài phạm vi các fix ảnh inspection; các flow đó chưa từng có persistence trước đây, nên không phải regression |

