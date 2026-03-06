# Workflow Quick Reference
## report_lms - Data Flow Cheat Sheet

---

## 🎯 5-Minute Overview

**Goal:** Transform basic inspection info → detailed inspection data → PDF report

**Path:** Create → List → Detail → Complete → PDF

---

## 📦 Data Models at Each Stage

### 1. Inspection (Basic)
```swift
Inspection {
    id, inspectionNumber, companyName, productName,
    orderCode, factory, quantity, status
}
```
**Used in:** CreateInspectionView, LMSHomeView

---

### 2. InspectionDetail (Rich)
```swift
InspectionDetail {
    id, inspectionNumber,
    sections: [InspectionSection],  // ← Nested structure
    orderQuantity, factoryName
}

InspectionSection {
    id, title, order, itemCount,
    fields: [InspectionField]  // ← Individual checkpoints
}

InspectionField {
    id, label, type, required, order
}
```
**Used in:** InspectionDetailView, FinalReportView

---

### 3. capturedPhotos (Photos)
```swift
[String: [UIImage]]
// fieldId → images
```
**Used in:** InspectionDetailViewModel → FinalReportView

---

### 4. PDFReportRequest (Unified DTO)
```swift
PDFReportRequest {
    inspectionDetail: InspectionDetail
    capturedImages: [String: [Data]]  // ← Converted from UIImage
    inspectorName: String              // ← From Keychain
    inspectionLocation: String
}
```
**Used in:** FinalReportView → GenerateHTMLPDFReportUseCase

---

## 🔄 Quick Flow Chart

```
CreateInspectionView
    ↓ [Submit]
    Creates: Inspection
    ↓ [Callback]
LMSHomeView
    ↓ [Tap Inspection]
    Pass: inspectionId + inspectionNumber
    ↓ [Navigate]
InspectionDetailView
    ↓ [Load Data]
    Fetch: InspectionDetail from API
    Capture: Photos ([String: [UIImage]])
    ↓ [Tap "Hoàn tất"]
    Pass: InspectionDetail + capturedPhotos
    ↓ [fullScreenCover]
FinalReportView
    ↓ [Build Request]
    Builder Pattern: PDFReportRequestBuilder
    ↓ [Generate]
    Create: PDFReportRequest
    ↓ [Execute Use Case]
GenerateHTMLPDFReportUseCase
    ↓ [Convert]
PDF Data (bytes)
```

---

## 🗂️ File Locations

| Type | File Path |
|------|-----------|
| **Views** | |
| Home | `Presentation/Modules/Home/LMSHomeView.swift` |
| Create | `Presentation/Modules/CreateInspectionView/CreateInspectionView.swift` |
| Detail | `Presentation/Modules/InspectionDetail/InspectionDetailView.swift` |
| Detail Content | `Presentation/Modules/InspectionDetail/InspectionDetailContentView.swift` |
| Final Report | `Presentation/Modules/InspectionDetail/FinalReportView.swift` |
| **ViewModels** | |
| Detail VM | `Presentation/Modules/InspectionDetail/InspectionDetailViewModel.swift` |
| Content VM | `Presentation/Modules/InspectionDetail/InspectionDetailContentViewModel.swift` |
| Final Report VM | `Presentation/Modules/InspectionDetail/FinalReportViewModel.swift` |
| **Entities** | |
| Inspection | `Domain/Entities/Inspection.swift` |
| InspectionDetail | `Domain/Entities/InspectionDetail.swift` |
| PDFReportRequest | `Domain/Entities/PDFReportRequest.swift` |
| Builder | `Domain/Entities/PDFReportRequestBuilder.swift` |
| **Use Cases** | |
| Fetch Detail | `Domain/UseCases/FetchInspectionDetailUseCase.swift` |
| Generate PDF | `Domain/UseCases/GenerateHTMLPDFReportUseCase.swift` |

---

## 🔍 Key Navigation Points

### 1. CreateInspectionView → LMSHomeView
```swift
// In CreateInspectionView
Button("Tạo kiểm tra") {
    let newInspection = Inspection(...)
    onInspectionCreated(newInspection)  // ← Callback
    dismiss()
}
```

### 2. LMSHomeView → InspectionDetailView
```swift
// In LMSHomeView
NavigationStack {
    List(inspections) { inspection in
        // ...
    }
}
.navigationDestination(for: Inspection.self) { inspection in
    InspectionDetailView(
        inspectionId: inspection.id,
        inspectionNumber: inspection.inspectionNumber
    )
}
```

### 3. InspectionDetailContentView → FinalReportView
```swift
// In InspectionDetailContentView
Button("Hoàn tất kiểm tra") {
    showFinalReport = true  // ← Triggers fullScreenCover
}

.fullScreenCover(isPresented: $showFinalReport) {
    FinalReportView(
        inspectionDetail: contentViewModel.inspectionDetail,
        capturedPhotos: contentViewModel.capturedPhotos
    )
}
```

### 4. FinalReportView → Camera (Photo Capture)
```swift
// In InspectionDetailView
.navigationDestination(isPresented: $viewModel.showCamera) {
    CameraView(source: .inspection) { images in
        viewModel.handlePhotoSelection(images)
    }
}
```

---

## 🔨 Builder Pattern Usage

### Quick Example
```swift
// In FinalReportViewModel.swift
func generateAndPreviewPDF() async {
    guard let detail = inspectionDetail else { return }
    
    do {
        // Step 1: Build request
        let request = try PDFReportRequestBuilder.withDefaults()  // ← Factory method
            .with(detail: detail)                                  // ← Add detail
            .with(images: capturedImages)                          // ← Add images
            .with(location: inspectionLocation)                    // ← Add location
            .build()                                               // ← Validate & create
        
        // Step 2: Execute use case
        let pdfData = try await generatePDFUseCase.execute(request: request)
        
        // Step 3: Display
        self.pdfData = pdfData
        isShowingPDFPreview = true
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

### Builder Methods
| Method | Purpose | Returns |
|--------|---------|---------|
| `.withDefaults()` | Factory method, gets username from Keychain | Builder |
| `.with(detail:)` | Add InspectionDetail | Builder |
| `.with(images:)` | Add captured images dictionary | Builder |
| `.with(location:)` | Add inspection location string | Builder |
| `.build()` | Validate and create PDFReportRequest | Request |

---

## 📸 Photo Management

### Capture Flow
```swift
// 1. User taps camera icon
InspectionFieldItemView(
    onCameraTap: { viewModel.openPhotoPicker(for: field.id) }
)

// 2. ViewModel sets selected field
func openPhotoPicker(for fieldId: String) {
    selectedFieldId = fieldId
    showCamera = true
}

// 3. Camera view opens via navigationDestination
.navigationDestination(isPresented: $showCamera) {
    CameraView { images in
        handlePhotoSelection(images)
    }
}

// 4. Save photos to dictionary
func handlePhotoSelection(_ images: [UIImage]) {
    guard let fieldId = selectedFieldId else { return }
    for image in images {
        savePhoto(image, for: fieldId)
    }
}

func savePhoto(_ image: UIImage, for fieldId: String) {
    if capturedPhotos[fieldId] == nil {
        capturedPhotos[fieldId] = []
    }
    capturedPhotos[fieldId]?.append(image)
}
```

### Photo Storage Structure
```
capturedPhotos: [String: [UIImage]]
                ↓       ↓
              fieldId  images array

Example:
[
    "field_001": [UIImage1, UIImage2],
    "field_002": [UIImage3],
    "field_003": [UIImage4, UIImage5, UIImage6]
]
```

---

## ⚙️ Use Case Execution

### Old Way (4 Parameters)
```swift
❌ Too many parameters, error-prone
let pdfData = try await generatePDFUseCase.execute(
    detail: detail,
    images: images,
    inspectorName: KeychainManager.getStoredUsername() ?? "",
    location: location
)
```

### New Way (1 Parameter)
```swift
✅ Type-safe, validated, single parameter
let request = try PDFReportRequestBuilder.withDefaults()
    .with(detail: detail)
    .with(images: images)
    .with(location: location)
    .build()

let pdfData = try await generatePDFUseCase.execute(request: request)
```

---

## 🎨 Layer Communication

```
Views/ViewModels (Presentation)
    ↓ Use
Entities/Use Cases (Domain)
    ↓ Define Protocols
Repository Protocols (Domain)
    ↓ Implemented by
Repositories (Data)
    ↓ Use
Services (Data)
```

### Example: Fetch InspectionDetail
```
InspectionDetailViewModel
    ↓ calls
FetchInspectionDetailUseCase
    ↓ depends on
InspectionRepositoryType (protocol)
    ↓ implemented by
InspectionRepository
    ↓ uses
InspectionService
```

---

## 🔐 KeychainManager Integration

### Where Used
```swift
// In PDFReportRequestBuilder
static func withDefaults() -> PDFReportRequestBuilder {
    PDFReportRequestBuilder(
        inspectionLocation: "",
        inspectorName: KeychainManager.getStoredUsername() ?? "Unknown"
        //              ↑ Auto-fetch from keychain
    )
}
```

### Why Useful
- ✅ Centralized username storage
- ✅ Automatically populated in PDF
- ✅ No manual passing required
- ✅ Fallback to "Unknown" if not found

---

## 🚦 Error Handling

### Builder Errors
```swift
enum PDFReportBuilderError: LocalizedError {
    case missingInspectionDetail
    case missingCapturedImages
    case invalidInspectorName
    
    var errorDescription: String? {
        switch self {
        case .missingInspectionDetail:
            return "Inspection detail is required"
        case .missingCapturedImages:
            return "Captured images dictionary is required"
        case .invalidInspectorName:
            return "Inspector name cannot be empty"
        }
    }
}
```

### Common Error Points
| Location | Error Type | Solution |
|----------|------------|----------|
| Builder.build() | Missing detail | Call .with(detail:) |
| Builder.build() | Missing images | Call .with(images:) |
| UseCase.execute() | Network error | Retry mechanism |
| PDF Generation | Invalid HTML | Check template |

---

## ✅ Validation Checklist

### Before Generating PDF
- [ ] InspectionDetail loaded?
- [ ] At least 1 field has photos?
- [ ] Inspector name available?
- [ ] Location entered (optional)?

### Builder Pattern Checklist
- [ ] Called `.withDefaults()`?
- [ ] Added `.with(detail:)`?
- [ ] Added `.with(images:)`?
- [ ] Called `.build()`?
- [ ] Wrapped in try-catch?

---

## 🎯 Common Tasks

### Task: Add New Field to Inspection
1. Update `InspectionField` in `Domain/Entities/InspectionField.swift`
2. Update `InspectionSection` to include new field
3. Update UI in `InspectionFieldItemView`
4. No change needed in PDFReportRequest ✅

### Task: Change PDF Generation Logic
1. Update `GenerateHTMLPDFReportUseCase`
2. No change needed in FinalReportViewModel ✅
3. PDFReportRequest structure remains same ✅

### Task: Add New PDF Parameter
1. Update `PDFReportRequest` entity
2. Update `PDFReportRequestBuilder` with new `.with()` method
3. Update `FinalReportViewModel` builder chain
4. Update `GenerateHTMLPDFReportUseCase.execute(request:)`

---

## 📚 Related Documentation

- **Detailed Analysis**: [WORKFLOW_DATA_FLOW.md](WORKFLOW_DATA_FLOW.md)
- **Visual Diagrams**: [WORKFLOW_DIAGRAM.md](WORKFLOW_DIAGRAM.md)
- **Architecture**: [.github/instructions/architecture.instructions.md](.github/instructions/architecture.instructions.md)
- **Code Standards**: [.github/instructions/code-standards.instructions.md](.github/instructions/code-standards.instructions.md)
- **Alternative Approaches**: [ALTERNATIVE_APPROACHES_PDF_REFACTORING.md](ALTERNATIVE_APPROACHES_PDF_REFACTORING.md)

---

## 🔖 Key Concepts

| Concept | Description |
|---------|-------------|
| **Clean Architecture** | Presentation → Domain ← Data |
| **Type-Safe Navigation** | NavigationStack + navigationDestination |
| **Builder Pattern** | Fluent API for complex object creation |
| **DTO Pattern** | Data Transfer Object (PDFReportRequest) |
| **Dependency Injection** | Container.shared.resolve() |
| **Async/Await** | Modern Swift concurrency |
| **@MainActor** | UI thread safety for ViewModels |

---

## ⏱️ Performance Notes

- InspectionDetail loaded on-demand (not upfront)
- Photos stored in memory until PDF generation
- Lazy loading for inspection sections
- PDF generation is async (non-blocking UI)

---

**Version:** 1.0  
**Last Updated:** January 2026  
**Quick Reference for:** report_lms Workflow
