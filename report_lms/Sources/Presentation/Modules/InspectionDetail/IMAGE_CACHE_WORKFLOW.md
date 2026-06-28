# Image Cache Workflow Documentation

## 📋 Tổng quan

Tài liệu này mô tả kiến trúc, luồng dữ liệu và memory budget của hệ thống cache ảnh trong `InspectionValidationView`.

Hệ thống gồm **2 RAM cache actor** + **ViewModel heap** phục vụ 3 loại ảnh khác nhau:

| Loại ảnh | Nguồn | Hiển thị |
|---|---|---|
| **Capture** | Camera (UIImage 12MP) | `images[].thumbnail` (800px) |
| **Remote** | Firebase Storage URL | `InspectionCachedImage` → 3-tier lookup |
| **Edit download** | Firebase Storage URL | `downloadImage(from:)` → `ImageCacheActor` |

---

## 🗂️ Cấu trúc file

```
Sources/
├── Common/
│   ├── Helpers/
│   │   ├── InspectionImageCacheActor.swift   # Cache durable cho ảnh inspection (Documents/)
│   │   ├── ImageCacheActor.swift              # Cache chung cho remote images (Caches/)
│   │   ├── PendingUploadStore.swift           # Tracks file paths chờ upload (UserDefaults)
│   │   └── PendingUploadRetryService.swift    # Retry upload khi app restart
│   └── Components/
│       └── CachedAsyncImage.swift             # AsyncImage + ImageCacheActor (dùng chung)
├── Domain/Entities/
│   └── FieldValidation.swift                  # InspectionImage struct
└── Presentation/Modules/InspectionDetail/InspectionValidation/
    ├── InspectionValidationViewModel.swift    # appendImages, uploadPhotosAndUpdateField
    └── Views/
        └── InspectionCachedImage.swift        # 3-tier loader cho remote images
```

---

## 🏗️ Kiến trúc hai cache actor

```
┌─────────────────────────────────────────────────────────────────────┐
│                    InspectionImageCacheActor                         │
│  Durable — Documents/ (iOS KHÔNG purge)                              │
│  RAM: max 60 entries, FIFO evict 30                                  │
│  Key: absolute file path                                             │
│                                                                      │
│  cacheCapture(image:thumbnail:inspectionId:fieldId:) → String?       │
│  ├── RAM: thumbnail 800px (shared ref với ViewModel)                 │
│  └── Disk: full-res JPEG 0.85 (~8MB)                                 │
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

---

## 🔄 Workflow: Chụp ảnh mới (`appendImages`)

```
User chụp ảnh
      │
      ▼
appendImages([UIImage])   @MainActor
      │
      ├── Phase 1 — Resize song song, tối đa 4 Task.detached đồng thời (priority .utility)
      │   │   (chunked để kiểm soát thermal budget — await từng chunk xong mới sang chunk tiếp)
      │   ├── Mỗi ảnh: resizedIfNeeded(800px) → UIImage
      │   ├── InspectionImage(image: thumb) → images.append()
      │   │   └── images[].thumbnail giữ UIImage 800px  [ViewModel heap]
      │   └── status .pending → .passed (auto-advance)
      │
      └── Phase 2 — Ghi disk tuần tự (Task, kế thừa MainActor)
          ├── Lấy thumbnail từ images[] (tránh resize lần 2)
          ├── InspectionImageCacheActor.cacheCapture(image:thumbnail:...)
          │   ├── RAM: addToRAM(filePath, thumbnail)   [shared ref với images[].thumbnail]
          │   └── Disk: full-res JPEG → Documents/inspection-images/<id>/<field>/capture_<uuid>.jpg
          ├── PendingUploadStore.addPending(filePath, inspectionId, fieldId)
          ├── images[idx].fileURL = URL(fileURLWithPath: path)
          └── (sau khi tất cả fileURLs set) saveValidation(status:, notifyParent: false)
                  └── currentUploadTask = Task {   ← chained: await prevTask?.value trước
                          → uploadPhotosAndUpdateField()
                          → updateInspectionStatus()    ← ghi status Firestore (.inProgress)
                          → onTaskCompleted()           ← activeUploadCount-- trong parent VM
                      }
```

**Tại sao Phase 2 mới trigger upload:**
Upload đọc `images[idx].fileURL` để lấy full-res từ disk. Nếu upload chạy trước Phase 2 hoàn tất, `fileURL` vẫn `nil` → fallback thumbnail 800px → chất lượng thấp.

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

---

## 🔄 Workflow: Retry sau khi app restart (`loadPendingCaptures`)

```
InspectionValidationView.onAppear
      │
      ▼
loadPendingCaptures()
      │
      ├── PendingUploadStore.getPendingFilePaths(inspectionId, fieldId)
      │   └── filter: FileManager.fileExists(atPath:)  (loại bỏ stale paths)
      │
      ├── [nếu chưa có local images trong ViewModel]
      │   └── InspectionImageCacheActor.loadFromPath(path) × N
      │       ├── RAM hit  → thumbnail 800px  ✅
      │       └── RAM miss → đọc full-res JPEG từ disk
      │                    → resize 800px + preparingForDisplay → addToRAM
      │
      ├── images.insert(contentsOf: loadedImages, at: 0)
      ├── onSilentSave?(retryValidation)  → startUploadSession (counter++)
      └── retryPendingUploads()
              ├── imagesForUpload = images.map { strip thumbnail nếu fileURL != nil }
              │   (thumbnails loaded bởi loadFromPath chỉ để hiển thị UI — upload đọc từ fileURL)
              └── uploadPhotosAndUpdateField(fieldId:images: imagesForUpload) → onTaskCompleted() (counter--)
```

---

## 🔄 Workflow: Upload (`uploadPhotosAndUpdateField`)

```
saveValidation(status:notifyParent:)   @MainActor
      │
      ├── Tạo imagesForUpload = self.images.map { strip thumbnail nếu fileURL != nil }
      │   └── Camera photos: thumbnail = nil  ← không giữ ~N×2MB trong function frame
      │       replaceImage (không có fileURL): thumbnail giữ nguyên (cần làm fallback upload)
      │
      └── currentUploadTask = Task { [weak self] in   ← chained: await prevTask?.value
              await uploadPhotosAndUpdateField(fieldId:images: imagesForUpload)
          }

uploadPhotosAndUpdateField(fieldId:images:)
      │
      ├── existingRemoteURLs = images.filter { isRemote }.compactMap { remoteURL }
      ├── localImages = images.filter { !isRemote }   ← thumbnail đã nil với camera photos
      │
      └── withTaskGroup(maxConcurrentSlots)   ← network + RAM aware
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
          │   └── FirebaseStorageService.uploadImageWithProgress(imageData:path:onProgress:)
          │       ├── withThrowingTaskGroup: race upload vs Task.sleep(90s)
          │       │   ├── Upload task: withTaskCancellationHandler {
          │       │   │       withCheckedThrowingContinuation { putData + observe(.progress) }
          │       │   │   } onCancel: { holder.task?.cancel() }   ← Firebase cancel → connection freed
          │       │   └── Timeout task: sleep(90s) → throw URLError(.timedOut)
          │       │       → tg.cancelAll() → onCancel fires → Firebase .cancel() → no zombie connection
          │       ├── onProgress → updateImageProgress (UI badge)
          │       ├── onDone    → markImageDone
          │       └── onFail    → markImageFailed (timeout cũng fail cleanly)
          │
          ├── for await (idx, url) in group   ← PROGRESSIVE RELEASE, on MainActor
          │   └── Với mỗi ảnh upload thành công ngay lập tức:
          │       ├── self.images[pos] = InspectionImage(remoteURL:)
          │       │   └── giải phóng UIImage thumbnail ~2MB khỏi MainActor heap NGAY
          │       └── Task.detached(priority: .background) {
          │               InspectionImageCacheActor.cacheRemote(thumb, remoteURL, ...)
          │           }   ← pre-populate RAM hit cho lần display tiếp
          │
          ├── storageService.updateFieldImageURLs(inspectionId:fieldId:imageURLs:)
          │   └── Serial write chain (pendingFieldWrite Task) — safe khi nhiều field đồng thời
          ├── PendingUploadStore.clearField(inspectionId:fieldId:)
          ├── onSilentSave?(updatedDraft)  ← propagate remote images lên capturedPhotos parent
          └── onUploadComplete?()
```

**Tại sao strip thumbnail trước khi truyền vào `uploadPhotosAndUpdateField`:**
Camera photos có `fileURL` → upload đọc từ disk, KHÔNG cần thumbnail. Nếu không strip: `images` parameter (value-type copy) giữ strong ref đến tất cả N UIImages trong suốt thời gian function chạy. Với 300 ảnh × 2MB = 600MB pinned cho đến khi function return → vượt jetsam threshold trên 4GB device.

**Tại sao timeout + cancellation nằm trong `FirebaseStorageService` (không phải ViewModel):**
Timeout trong ViewModel chỉ giải phóng slot, nhưng Firebase `StorageUploadTask` vẫn tiếp tục chạy ngầm — giữ URLSession connection. URLSession có max 6 connections/host. Sau N timeout, tất cả 6 connections bị chiếm bởi "zombie" tasks → upload mới không mở được connection → kẹt mãi ở "Đang chờ". Đặt cancel tại Firebase layer (`holder.task?.cancel()`) → Firebase gọi completion callback với lỗi cancelled → `withCheckedThrowingContinuation` resume → connection được đóng ngay.

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

## 🔄 Workflow: Retry tại app launch (`PendingUploadRetryService`)

```
App launch
      │
      ▼
PendingUploadRetryService.retryAllPendingUploads()
      │
      ├── PendingUploadStore.getAllPendingInspectionIds()
      └── Mỗi (inspectionId, fieldId, paths):
          └── Task { uploadField(...) }
              │
              ├── Đọc full-res JPEG trực tiếp từ disk (KHÔNG qua RAM cache)
              │   └── Task.detached { Data(contentsOf: path) → UIImage(data:) }
              │
              ├── UIImage.prepareForUpload() → Data
              ├── uploadUseCase.execute(imageData:inspectionId:)
              └── storageService.updateFieldImageURLs(...)
```

**Quan trọng:** `PendingUploadRetryService` đọc disk trực tiếp (không qua `loadFromPath`) để đảm bảo luôn upload full-res, bất kể RAM cache đang chứa thumbnail hay không.

---

## 💾 Memory Budget

### Kích thước ảnh trong RAM

| Loại | Kích thước RAM | Ghi chú |
|---|---|---|
| Capture thumbnail (800px) | ~2MB | `images[].thumbnail` + `InspectionImageCacheActor.ram` (shared ref) |
| Remote display (1024px) | ~4MB | `InspectionImageCacheActor.ram` |
| Full-res 12MP decoded | ~48MB | Chỉ tồn tại tạm trong pipeline upload/edit, không lưu RAM |

### Giới hạn và eviction

| Cache | Max entries | Evict | Evictable bởi memory warning? |
|---|---|---|---|
| `InspectionImageCacheActor.ram` | 60 | FIFO 30 | ✅ `evictAllRAM()` |
| `ImageCacheActor.ram` | 100 | FIFO 50 | ❌ (tự FIFO) |
| `images[].thumbnail` (ViewModel) | Không giới hạn | Progressive trong `for await` upload loop; hoặc khi ViewModel deallocate | ✅ (sau mỗi upload) |

### Worst case (60 remote images trong `InspectionImageCacheActor`)

```
60 entries × 4MB = 240MB  (InspectionImageCacheActor.ram)
N captures × 2MB = ~20MB  (shared ref ViewModel + actor)
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

### 3. `cacheCapture` nhận thumbnail từ Phase 1

Tránh resize lần 2 (Phase 1 đã resize 12MP → 800px):

```swift
// Phase 1: resize → UIImage thumb (trong images[].thumbnail)
// Phase 2: truyền thumb vào cacheCapture, không resize lại
cacheCapture(image: originalFullRes, thumbnail: thumb, ...)
```

### 4. `promotingKeys` deduplication trong `cacheRemote`

Nhiều `InspectionCachedImage` cell cùng URL → tất cả đều hit `ImageCacheActor` → tất cả launch `Task.detached { cacheRemote(...) }`. Actor serialize nhưng vẫn encode JPEG + ghi disk nhiều lần. `promotingKeys` guard ngăn redundant work.

---

## ⚠️ Giới hạn đã biết

| Vấn đề | Nguyên nhân | Trade-off chấp nhận được |
|---|---|---|
| `images[].thumbnail` giữ trong upload session | Thumbnail không strip được xóa progressive trong `for await` loop, nhưng nếu upload task bị cancel trước khi loop kết thúc, thumbnails còn lại giải phóng khi ViewModel deallocate | Acceptable: cancel path hiếm, ViewModel deallocate tiếp theo |
| `ImageCacheActor` không resize | Dùng chung toàn app, resize có thể break edit flow | Tự FIFO evict tại 100 entries |
| Disk capture không xoá sau upload | `PendingUploadStore.clearField` clear tracking nhưng không xoá file | `evictInspection()` dọn khi delete/complete |
| `evictAllRAM()` log MB giải phóng thấp hơn thực tế | Log hardcode `count × 2 MB` — đúng với capture (800px) nhưng sai với remote (1024px = ~4MB/entry) | Chỉ ảnh hưởng con số trong log, không ảnh hưởng logic eviction |
| `replaceImage(at:with:)` upload chất lượng thấp hơn | Khi thay ảnh: tạo `InspectionImage` chỉ có thumbnail (không có `fileURL`) → upload dùng thumbnail 800px thay vì full-res JPEG | Ảnh chỉnh sửa hiếm gặp, chấp nhận được trong production |
| `isOnWiFiOrEthernet` block cooperative thread | Dùng `DispatchSemaphore.wait()` để lấy network snapshot — block thread trong ~vài ms | Chỉ gọi 1 lần mỗi upload batch, không gây ANR thực tế |
