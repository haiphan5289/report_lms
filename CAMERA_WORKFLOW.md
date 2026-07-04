# Camera Workflow Documentation

## 📋 Tổng quan

Tài liệu này mô tả chi tiết kiến trúc, luồng dữ liệu, và cách tích hợp Camera workflow trong ứng dụng report_lms.

Camera workflow hỗ trợ chụp ảnh từ nhiều nguồn (`CameraSource`) khác nhau, với các quy tắc riêng về số lượng ảnh và flash.

---

## 🗂️ Cấu trúc file

```
Sources/Presentation/Modules/Camera/
├── CameraView.swift                  # SwiftUI View chính, nhận source + callback
├── CameraViewModel.swift             # @MainActor ViewModel, quản lý state
├── CameraController.swift            # AVFoundation wrapper (session, capture, zoom)
└── CameraPreviewRepresentable.swift  # UIViewRepresentable bridge cho preview layer
```

---

## 🏗️ Kiến trúc

```
┌──────────────────────────────────────────────────────┐
│                   Presentation Layer                  │
│                                                      │
│   CameraView (SwiftUI)                               │
│   ├── @StateObject CameraViewModel(source:)          │
│   ├── CameraPreviewRepresentable(previewLayer:)      │
│   ├── bottomControls  (flash, capture, switch, zoom) │
│   └── imageList       (thumbnail strip)              │
│                                                      │
│   CameraViewModel (@MainActor ObservableObject)      │
│   ├── @Published capturedImages, flashMode, zoom...  │
│   ├── enforces source.allowsMultiplePhotos           │
│   └── exposes previewLayer, isFlashAvailable         │
└──────────────────┬───────────────────────────────────┘
                   │  async/await
┌──────────────────▼───────────────────────────────────┐
│              AVFoundation Layer                       │
│                                                      │
│   CameraController (NSObject)                        │
│   ├── sessionQueue (serial DispatchQueue)            │
│   ├── AVCaptureSession                               │
│   ├── AVCaptureDeviceInput (front / back)            │
│   ├── AVCapturePhotoOutput                           │
│   └── lazy AVCaptureVideoPreviewLayer                │
└──────────────────────────────────────────────────────┘
```

---

## 🔄 Luồng hoạt động

### Bước 1: Mở Camera

**File:** `CameraView.swift` — `.task { await viewModel.setupCamera() }`

```
CameraView.onAppear
    └── viewModel.setupCamera()
            ├── checkCameraPermission()
            │       ├── .authorized  → tiếp tục
            │       └── .denied / .restricted → showPermissionAlert = true → DỪNG
            ├── cameraController.setupSession()   [chạy trên sessionQueue]
            │       ├── beginConfiguration()
            │       ├── AVCaptureDeviceInput (back camera)
            │       ├── AVCapturePhotoOutput (highResolution = true)
            │       └── commitConfiguration()
            ├── isFlashAvailable = cameraController.isFlashAvailable
            └── cameraController.startSession()   [chạy trên sessionQueue]
```

---

### Bước 2: Hiển thị Preview

**File:** `CameraPreviewRepresentable.swift`

```
CameraView
    └── CameraPreviewRepresentable(previewLayer: viewModel.previewLayer)
            └── makeUIView()
                    └── CameraPreviewView
                            └── layer.addSublayer(previewLayer)
                                    ↓
                            layoutSubviews() → previewLayer.frame = bounds
```

> `previewLayer` là `lazy var` trên `CameraController` — chỉ tạo một lần duy nhất, không bị duplicate khi SwiftUI re-render.

---

### Bước 3: Chụp ảnh

**File:** `CameraViewModel.swift` → `CameraController.swift`

```
User tap nút chụp
    └── viewModel.capturePhoto()
            ├── guard source.allowsMultiplePhotos || capturedImages.isEmpty
            ├── guard !isAtPhotoLimit (maxPhotos, VD 20 với .inspection)
            └── cameraController.capturePhoto(flashMode: flashMode)
                    ├── captureCompletion = completion   [main thread]
                    └── sessionQueue.async
                            ├── AVCapturePhotoSettings(flashMode: ...)
                            └── photoOutput.capturePhoto(with: settings, delegate: self)
                                    ↓ (AVFoundation callback queue)
                            photoOutput(_:didFinishProcessingPhoto:)
                                    ├── build Result<UIImage, Error>
                                    └── DispatchQueue.main.async
                                            ├── captureCompletion?(.success(image))
                                            └── captureCompletion = nil
                                                    ↓
                                    Task { @MainActor in await self.persistCapture(image) }
                                            ├── writePendingFile(image:id:in: pendingCapturesDir)
                                            │       └── JPEG 0.85 → pending_<uuid>.jpg  ← GHI DISK
                                            │           NGAY, trước khi ảnh kịp hiện trong preview
                                            └── capturedImages.append(CapturedPhoto(id:image:fileURL:))
```

**Vì sao ghi disk ngay ở bước này (thêm sau bug "kill app mất ảnh"):** trước đây `capturedImages` chỉ là `[UIImage]` — sống hoàn toàn trong RAM cho tới khi cả pipeline (Done → resize → upload commit) chạy xong, có thể mất vài giây. Nếu app bị kill/crash trong khoảng đó, ảnh mất vĩnh viễn, không cách nào phục hồi. Giờ mỗi ảnh có bytes an toàn trên disk **trong vòng một khung hình** sau khi chụp — xem chi tiết đầy đủ ở [`IMAGE_CACHE_WORKFLOW.md` § Kiến trúc capture-time durability](report_lms/Sources/Presentation/Modules/InspectionDetail/IMAGE_CACHE_WORKFLOW.md).

---

### Bước 4: Chuyển camera (front ↔ back)

```
User tap nút chuyển camera
    └── viewModel.switchCamera()
            └── Task { try await cameraController.switchCamera() }
                    └── withCheckedThrowingContinuation
                            └── sessionQueue.async → switchCameraSync()
                                    ├── beginConfiguration()
                                    ├── removeInput(currentInput)
                                    ├── addInput(newInput)
                                    └── commitConfiguration()
                    └── isFlashAvailable = cameraController.isFlashAvailable  [refresh]
```

---

### Bước 5: Điều chỉnh zoom

```
Slider onChange → viewModel.updateZoom(factor)
    ├── zoomFactor = factor   [@Published → UI update]
    └── cameraController.setZoom(factor)
            └── device.lockForConfiguration()
                device.videoZoomFactor = clamp(factor, 1.0 ... maxZoom)
                device.unlockForConfiguration()
```

---

### Bước 6: Flash

Flash state được quản lý hoàn toàn trong `CameraViewModel`, không còn ghi vào `AVCaptureDevice.flashMode` (deprecated). Mode được truyền vào `AVCapturePhotoSettings` tại thời điểm chụp.

```
User tap flash button
    └── viewModel.toggleFlash()
            └── flashMode cycles: .off → .on → .auto → .off

Khi chụp:
    └── cameraController.capturePhoto(flashMode: viewModel.flashMode)
            └── settings.flashMode = flashMode   ← đặt ở đây, không phải trên device
```

---

### Bước 7: Xác nhận & trả ảnh

```
User tap "Done"
    ├── let photos = viewModel.capturedImages
    ├── viewModel.finishedHandoff(keepFiles: keepsFilesAfterHandoff)
    │       ├── keepFiles: true  (rich init)  → giữ pending_*.jpg, caller tự commit
    │       └── keepFiles: false (legacy init) → xoá pending_*.jpg ngay (caller chỉ cần UIImage)
    ├── onPhotosCaptured(photos)   [callback về caller — [CapturedPhoto] hoặc [UIImage] tuỳ init]
    └── dismiss()
```

**2 initializer** — chọn tự động theo tham số truyền vào tại call site, không đổi cách gọi của các flow không cần an toàn disk:

```swift
// Legacy — nhận [UIImage], KHÔNG có safety-net disk (giữ đúng risk profile như trước)
CameraView(source: .errorReport) { images in
    viewModel.attachImages(images)
}

// Rich — nhận [CapturedPhoto] (ảnh + fileURL đã ghi disk), dùng cho flow inspection
CameraView(source: .inspection, inspectionId: id, fieldId: fieldId) { photos in
    viewModel.appendImages(photos)   // hoặc handleQuickCapture(photos)
}
```

---

### Bước 8: Đóng Camera

```
CameraView.onDisappear   ← chạy với MỌI cách thoát: Done, Cancel, vuốt dismiss, huỷ permission alert
    ├── viewModel.stopCamera()
    │       └── cameraController.stopSession()
    │               └── sessionQueue.async → captureSession.stopRunning()
    └── viewModel.finishedHandoff(keepFiles: false)
            └── No-op nếu Done đã claim ảnh (capturedImages rỗng lúc này)
                Ngược lại: xoá sạch pending_*.jpg còn sót (Cancel/vuốt dismiss) — không rác
```

---

## 📦 CameraSource

| Source | `allowsMultiplePhotos` | `maxPhotos` | Sử dụng |
|---|---|---|---|
| `.errorReport` | `true` | không giới hạn | Mở từ nút Report trên ErrorHomeView |
| `.inspection` | `true` | 20 | Inspection flow (validation screen + quick-capture field-list) |
| `.general` | `true` | không giới hạn | Chụp ảnh chung |

```swift
// Legacy — [UIImage], không có safety-net disk
CameraView(source: .errorReport) { images in
    viewModel.attachImages(images)
}
.environmentObject(LocalizationManager.shared)

// Rich — [CapturedPhoto], safety-net disk (dùng cho flow inspection)
CameraView(source: .inspection, inspectionId: id, fieldId: fieldId) { photos in
    viewModel.appendImages(photos)
}
.environmentObject(LocalizationManager.shared)
```

---

## 🧵 Thread Safety

| Thao tác | Queue |
|---|---|
| `setupSession` / `switchCamera` / `startSession` / `stopSession` | `sessionQueue` (serial) |
| `photoOutput.capturePhoto` | `sessionQueue` |
| `captureCompletion` — set | Main thread (từ `@MainActor` ViewModel) |
| `captureCompletion` — invoke + clear | `DispatchQueue.main.async` (từ delegate) |
| Cập nhật `@Published` properties | Main thread (`@MainActor`) |

---

## ⚠️ Lưu ý quan trọng

1. **`previewLayer` là lazy** — Không bao giờ gọi `cameraController.previewLayer` nhiều lần mong đợi object khác nhau. Nó luôn trả về cùng một instance.

2. **Flash mode** — Không set `device.flashMode` trực tiếp (deprecated từ iOS 10). Luôn dùng `AVCapturePhotoSettings.flashMode`.

3. **Single-photo enforcement** — `CameraViewModel.capturePhoto()` tự guard theo `source.allowsMultiplePhotos`. Caller không cần tự kiểm tra.

4. **`isFlashAvailable`** — Giá trị này thay đổi khi switch camera (camera trước thường không có flash). ViewModel tự refresh sau mỗi `switchCamera`.

5. **`@EnvironmentObject LocalizationManager`** — `CameraView` yêu cầu `LocalizationManager` phải được inject qua environment. Thiếu sẽ crash ở runtime.

---

---

## ✏️ Image Editor

### Tổng quan

`ImageEditorView` cho phép người dùng chỉnh sửa ảnh sau khi chụp (vẽ, xóa nét, thêm chú thích văn bản, xoay, zoom) trước khi lưu lại vào danh sách.

### Cấu trúc file

```
Sources/Presentation/Modules/Home/ErrorHome/PhotoCaptureErrorReview/
├── ImageEditorView.swift        # SwiftUI View — toolbar, canvas, gestures
└── ImageEditorViewModel.swift   # @MainActor ViewModel — PencilKit, composite
```

### Kiến trúc

```
PhotoCaptureErrorReviewView
    └── .sheet(isPresented: $showImageEditor)
            └── ImageEditorView(image: editingUIImage) { editedImage in
                    viewModel.replaceImage(at: selectedIndex, with: editedImage)
                    onImagesUpdated(viewModel.images)
                }
```

### Cách mở editor

1. User tap nút `⋯` trên thumbnail → `showImageMenu = true`
2. User chọn "Chỉnh sửa" → `handleEditImage()` chạy:
   - `.local(image)` → dùng trực tiếp
   - `.remote(url)` → download trước (`viewModel.downloadImage(from:)`) rồi mới mở
3. `showImageEditor = true` → sheet hiện `ImageEditorView`

### Luồng lưu ảnh

```
User tap "Lưu"
    └── viewModel.save(canvasSize:)
            └── compositeImage(canvasSize:)
                    ├── rotatedSourceImage()     ← áp dụng rotation
                    ├── draw base image
                    ├── draw PKCanvasView drawing (scale về kích thước gốc)
                    └── draw text annotations    (scale tọa độ về pixel gốc)
    └── onSaved(editedImage)
            └── PhotoCaptureErrorReviewViewModel.replaceImage(at: index, with: editedImage)
            └── onImagesUpdated(viewModel.images)   ← notify parent
    └── dismiss()
```

> Ảnh **không** được lưu vào Photos Library — chỉ thay thế trong danh sách nội bộ.

### Tính năng

| Tính năng | Mô tả |
|---|---|
| Vẽ tự do | `PKInkingTool(.pen)` — màu và độ dày tùy chọn |
| Tẩy | `PKEraserTool(.bitmap)` |
| Thêm văn bản | Alert nhập text → `DraggableTextView` (kéo để di chuyển, giữ lâu để xóa) |
| Xoay | 90° CW mỗi lần tap — `rotationAngle += 90` |
| Zoom | Pinch 1×–5× qua `MagnificationGesture` + `.simultaneousGesture` |
| Pan | Drag khi đang zoom > 1× |
| Reset zoom | Double-tap → spring về 1× |
| Undo / Redo | `PKCanvasView.undoManager` |

### Lưu ý kỹ thuật

- **PKCanvasView gesture conflict**: `PKCanvasView` là subclass của `UIScrollView`. Phải set `canvasView.isScrollEnabled = false` để `MagnificationGesture` của SwiftUI nhận được pinch event.
- **`simultaneousGesture`**: tất cả gesture (zoom, pan) phải dùng `.simultaneousGesture` để PKCanvasView vẫn nhận drawing touch song song.
- **Rotation + aspect-fit**: khi xoay 90°/270°, `displaySize` hoán đổi width/height để `aspectFitSize()` tính đúng khung hiển thị.
- **Composite scaling**: drawing từ `PKCanvasView` được scale từ `canvasSize` (màn hình) về `imgSize` (pixel gốc) khi render `UIGraphicsImageRenderer`.

---

## 🗺️ Sơ đồ state

```
                    ┌─────────────┐
                    │   Init      │
                    │ (no camera) │
                    └──────┬──────┘
                           │ .task setupCamera()
              ┌────────────▼──────────────┐
              │   Permission Check        │
              └────┬──────────────────────┘
         denied    │           │ authorized
              ┌────▼────┐  ┌───▼───────────────┐
              │ Alert   │  │  Session Setup     │
              │(settings│  │  (sessionQueue)    │
              │ / cancel│  └───────┬────────────┘
              └─────────┘         │ success
                             ┌────▼──────────┐
                             │    Live       │
                             │   Preview     │◄──── zoom / flash / switch
                             └────┬──────────┘
                                  │ tap capture
                             ┌────▼──────────┐
                             │   Capturing   │
                             └────┬──────────┘
                                  │ success → persistCapture (ghi pending_<uuid>.jpg xuống disk)
                             ┌────▼──────────┐
                             │  Thumbnail    │◄──── delete image (xoá cả file pending_*.jpg)
                             │   Strip       │
                             └────┬──────────┘
                                  │ tap Done                    │ Cancel / vuốt dismiss / permission cancel
                             ┌────▼──────────┐              ┌────▼──────────────┐
                             │ finishedHandoff│              │ finishedHandoff    │
                             │ (keepFiles:    │              │ (keepFiles: false) │
                             │  tuỳ init)     │              │  qua .onDisappear  │
                             └────┬──────────┘              └────┬───────────────┘
                                  │                                │ xoá sạch pending_*.jpg còn sót
                             ┌────▼──────────┐                     ▼
                             │ onPhotosCaptured│                (không có ảnh nào được trả về)
                             │  callback      │
                             └───────────────┘
```
