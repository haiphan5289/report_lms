# 🏗️ Camera Feature Architecture

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER                          │
│                     (SwiftUI + ViewModels)                       │
└─────────────────────────────────────────────────────────────────┘
                                │
                                │
┌───────────────────────────────┴───────────────────────────────┐
│                                                                 │
│  ┌───────────────────────┐       ┌──────────────────────┐    │
│  │ InspectionDetailView  │       │     CameraView       │    │
│  │   (SwiftUI)           │──────▶│   (SwiftUI)          │    │
│  │                       │       │                      │    │
│  │ - Inspection fields   │       │ - Camera preview     │    │
│  │ - Camera icon button  │       │ - Flash controls     │    │
│  │ - Photo indicators    │       │ - Zoom slider        │    │
│  └───────────────────────┘       │ - Capture button     │    │
│             │                     │ - Camera switch      │    │
│             │                     └──────────────────────┘    │
│             │                              │                   │
│             ▼                              ▼                   │
│  ┌───────────────────────┐       ┌──────────────────────┐    │
│  │InspectionDetailVM     │       │   CameraViewModel    │    │
│  │   (@MainActor)        │       │   (@MainActor)       │    │
│  │                       │       │                      │    │
│  │ - capturedPhotos      │◀──────│ - capturedImage      │    │
│  │ - selectedFieldId     │       │ - flashMode          │    │
│  │ - showCamera          │       │ - zoomFactor         │    │
│  │ - handlePhotoSelection│       │ - permissionStatus   │    │
│  └───────────────────────┘       └──────────────────────┘    │
│                                            │                   │
│                                            ▼                   │
│                                   ┌──────────────────────┐    │
│                                   │  CameraController    │    │
│                                   │  (AVFoundation)      │    │
│                                   │                      │    │
│                                   │ - captureSession     │    │
│                                   │ - videoDeviceInput   │    │
│                                   │ - photoOutput        │    │
│                                   │ - switchCamera()     │    │
│                                   │ - setFlashMode()     │    │
│                                   │ - setZoom()          │    │
│                                   │ - capturePhoto()     │    │
│                                   └──────────────────────┘    │
│                                            │                   │
│                                            ▼                   │
│                                   ┌──────────────────────┐    │
│                                   │CameraPreview         │    │
│                                   │ Representable        │    │
│                                   │ (UIKit Bridge)       │    │
│                                   │                      │    │
│                                   │ - AVCaptureVideo     │    │
│                                   │   PreviewLayer       │    │
│                                   └──────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Component Relationships

### 1. **User Interaction Flow**

```
User Taps Camera Icon
        │
        ▼
InspectionDetailView
        │
        ▼
InspectionDetailViewModel.openPhotoPicker()
        │
        ▼
Sets showCamera = true
        │
        ▼
CameraView Presented (fullScreenCover)
        │
        ▼
CameraViewModel.setupCamera()
        │
        ▼
CameraController.setupSession()
        │
        ▼
Camera Preview Shows
```

### 2. **Photo Capture Flow**

```
User Taps Capture Button
        │
        ▼
CameraViewModel.capturePhoto()
        │
        ▼
CameraController.capturePhoto()
        │
        ▼
AVCapturePhotoCaptureDelegate
        │
        ▼
CameraViewModel.capturedImage = UIImage
        │
        ▼
Preview Screen Shows
        │
        ▼
User Taps "Hoàn thành" (Accept)
        │
        ▼
onPhotoCaptured(image) callback
        │
        ▼
InspectionDetailViewModel.handlePhotoSelection()
        │
        ▼
Photo Saved to capturedPhotos[fieldId]
        │
        ▼
Camera Dismisses
```

### 3. **Permission Handling Flow**

```
Camera View Task
        │
        ▼
CameraViewModel.setupCamera()
        │
        ▼
checkCameraPermission()
        │
        ├─▶ Not Determined → Request Access
        │   │
        │   ├─▶ Authorized → Setup Camera
        │   └─▶ Denied → Show Alert
        │
        ├─▶ Authorized → Setup Camera
        │
        └─▶ Denied/Restricted → Show Alert
                │
                ▼
        User Taps "Mở Cài đặt"
                │
                ▼
        Opens iOS Settings
```

## Data Flow

### Camera State Management

```swift
@Published var capturedImage: UIImage?           // Current photo
@Published var flashMode: AVCaptureDevice.FlashMode // Flash state
@Published var zoomFactor: CGFloat               // Zoom level
@Published var isShowingPreview: Bool            // Preview mode
@Published var errorMessage: String?             // Error handling
@Published var showPermissionAlert: Bool         // Permission UI
@Published var cameraPermissionStatus            // Permission state
```

### Inspection Integration

```swift
@Published var capturedPhotos: [String: UIImage] // fieldId: image
@Published var selectedFieldId: String?          // Current field
@Published var showCamera: Bool                  // Camera modal
```

## Layer Responsibilities

### **Presentation Layer**

#### **Views** (SwiftUI)
- User interface rendering
- User interaction handling
- Navigation/presentation
- UI state binding

#### **ViewModels** (@MainActor)
- State management
- Business logic coordination
- User action handling
- Data transformation

### **Camera Layer**

#### **CameraController** (AVFoundation)
- Hardware camera access
- Session management
- Device configuration
- Photo capture

#### **CameraPreviewRepresentable** (UIKit Bridge)
- SwiftUI ↔ UIKit bridge
- Preview layer management
- Layout handling

## Clean Architecture Compliance

✅ **Separation of Concerns**
- Views: UI only
- ViewModels: State + Logic
- Controller: Hardware abstraction

✅ **Dependency Direction**
- View → ViewModel → Controller
- No reverse dependencies

✅ **Testability**
- ViewModel can be unit tested
- Controller can be mocked
- Views can use preview providers

✅ **Reusability**
- CameraView is standalone component
- Can be used in other modules
- No tight coupling to Inspection

## Technology Stack

| Component | Technology |
|-----------|-----------|
| UI Framework | SwiftUI |
| State Management | Combine (@Published) |
| Concurrency | async/await |
| Camera API | AVFoundation |
| UIKit Bridge | UIViewRepresentable |
| Threading | @MainActor |
| Error Handling | LocalizedError |

## File Organization

```
Presentation/Modules/Camera/
├── CameraView.swift                 # Main UI
├── CameraViewModel.swift            # State + Logic
├── CameraController.swift           # AVFoundation
└── CameraPreviewRepresentable.swift # UIKit Bridge
```

## Integration Pattern

```swift
// Presentation: Full-screen modal
.fullScreenCover(isPresented: $viewModel.showCamera) {
    CameraView { image in
        // Callback integration
        viewModel.handlePhotoSelection(image)
    }
}
```

## Performance Characteristics

- **Camera Startup**: ~0.5s (device dependent)
- **Photo Capture**: ~0.1-0.2s
- **Memory Usage**: Moderate (camera buffer + captured image)
- **Battery Impact**: High during use (camera hardware)
- **Thread Safety**: ✅ @MainActor for UI updates

## Security & Privacy

- ✅ Camera permission required (NSCameraUsageDescription)
- ✅ Permission denial handled gracefully
- ✅ No photo storage without user action
- ✅ Photos stored in app memory only (until saved)
- ✅ No network transmission (handled by parent)

## Error Handling

```swift
enum CameraError: LocalizedError {
    case deviceNotAvailable
    case cannotAddInput
    case cannotAddOutput
    case flashNotAvailable
    case imageCreationFailed
    case permissionDenied
}
```

All errors displayed to user in Vietnamese with actionable messages.

---

**This architecture ensures:**
- Clean separation of concerns
- Easy testing and maintenance
- Reusable components
- Proper error handling
- Thread-safe operations
- User-friendly experience
