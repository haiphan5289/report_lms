# Camera Feature Implementation

## 📸 Camera Capture Feature

A custom camera implementation for product/material inspection in the LMS application.

### ✅ Features Implemented

- ✅ Front/Back camera switch
- ✅ Flash toggle (Off → On → Auto)
- ✅ Zoom functionality (1x - 5x)
- ✅ Photo preview with Accept/Retake buttons
- ✅ Camera permission handling with user-friendly alerts
- ✅ Full-screen modal presentation
- ✅ Integration with existing inspection flow

### 📁 File Structure

```
Presentation/Modules/Camera/
├── CameraView.swift              # Main camera UI
├── CameraViewModel.swift         # Camera state management
├── CameraController.swift        # AVFoundation camera logic
└── CameraPreviewRepresentable.swift  # UIKit bridge for camera preview
```

### 🔑 Required: Camera Permission Setup

**IMPORTANT:** Add camera permission to your project:

#### Option 1: Using Xcode UI (Recommended)
1. Open project in Xcode
2. Select `report_lms` target
3. Go to **Info** tab
4. Add new key: `Privacy - Camera Usage Description`
5. Value: `Ứng dụng cần truy cập camera để chụp ảnh sản phẩm trong quá trình kiểm tra`

#### Option 2: Manual Info.plist (if exists)
Add to `Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Ứng dụng cần truy cập camera để chụp ảnh sản phẩm trong quá trình kiểm tra</string>
```

#### Option 3: Using .xcodeproj modification
The camera permission should be added to your project's build settings. If not present, the app will crash when accessing the camera.

### 🎨 UI Components

#### Camera Screen
- **Top Left**: "Hủy bỏ" (Cancel) button
- **Top Right**: Flash toggle button
- **Center**: Live camera preview
- **Bottom**: Zoom slider with +/- magnifying glass icons
- **Bottom Center**: Large white capture button
- **Bottom Right**: Camera switch button

#### Preview Screen
- Full-screen captured image
- **Bottom Left**: "Chụp lại" (Retake) button with counter-clockwise icon
- **Bottom Right**: "Hoàn thành" (Complete) button with checkmark icon

### 🔄 Integration Flow

```swift
// InspectionDetailView presents camera
.fullScreenCover(isPresented: $viewModel.showCamera) {
    CameraView { image in
        viewModel.handlePhotoSelection(image)
    }
}
```

### 🧪 Usage Example

```swift
// User taps inspection field camera icon
InspectionFieldItemView(
    fieldName: field.label,
    hasPhoto: viewModel.hasPhoto(for: field.id),
    onCameraTap: { 
        viewModel.openPhotoPicker(for: field.id) // Opens camera
    }
)
```

### ⚙️ Camera Capabilities

- **Resolution**: High resolution photo capture
- **Flash Modes**: Off, On, Auto
- **Zoom Range**: 1.0x to 5.0x (device dependent)
- **Camera Positions**: Front and Back
- **Orientation**: Portrait mode

### 🔒 Permission Handling

The app handles camera permissions gracefully:

1. **First Time**: Requests camera access automatically
2. **Denied**: Shows alert with "Open Settings" option
3. **Restricted**: Shows appropriate error message

### 📱 Supported iOS Versions

- iOS 15.0+ (SwiftUI async/await requirements)
- Works on all iPhone models with camera

### 🎯 Clean Architecture Integration

- **Presentation Layer**: CameraView, CameraViewModel
- **Uses existing**: InspectionDetailViewModel.handlePhotoSelection()
- **No Domain/Data changes**: Pure UI feature

### 🚀 Next Steps (Optional Enhancements)

- [ ] Add grid overlay for better alignment
- [ ] Implement photo editing (crop, rotate)
- [ ] Add multiple photo capture per field
- [ ] Implement photo compression before upload
- [ ] Add photo gallery view for captured images
- [ ] Support video recording mode

### 🐛 Troubleshooting

**App crashes on camera access:**
- Verify camera permission is added (see above)
- Check device has camera capability

**Camera preview not showing:**
- Ensure device is not in simulator (use real device)
- Check camera permissions in Settings

**Flash not working:**
- Some devices don't support flash
- Check `isFlashAvailable` property

### 📝 Vietnamese Localization

All UI text is in Vietnamese:
- "Hủy bỏ" - Cancel
- "Hoàn thành" - Complete
- "Chụp lại" - Retake
- Error messages in Vietnamese

### 🔧 Technical Details

- Uses `AVFoundation` for camera control
- `AVCaptureSession` for video capture
- `AVCapturePhotoOutput` for high-quality photos
- SwiftUI + UIViewRepresentable bridge for preview
- @MainActor for thread-safe UI updates
