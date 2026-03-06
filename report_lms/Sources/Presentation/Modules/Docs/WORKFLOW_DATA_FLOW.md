# Workflow & Data Flow Analysis
## Complete Data Transformation Flow in report_lms

---

## 📋 Overview

This document describes the complete workflow and data model transformation from inspection creation to PDF generation in the report_lms application.

**Flow Summary:**
```
LMSHomeView → CreateInspectionView → LMSHomeView → InspectionDetailView 
→ InspectionDetailContentView → FinalReportView → PDF
```

---

## 🎯 Complete Workflow Stages

### **Stage 1: Inspection Creation**
**View:** `CreateInspectionView`

**Purpose:** User creates a new inspection record with basic information.

**Data Model:** `Inspection` (Domain Entity)

**Properties:**
```swift
struct Inspection: Identifiable, Equatable {
    let id: String
    let inspectionNumber: String
    let companyName: String
    let productName: String
    let productCode: String
    let orderCode: String
    let inspectionType: String
    let quantity: Int
    let factory: String
    let productionUnit: String
    let createdAt: Date
    let inspectorId: String
    let status: InspectionStatus
}
```

**Navigation:**
```swift
// In CreateInspectionView
Button("Tạo kiểm tra") {
    // Create inspection
    let newInspection = Inspection(...)
    
    // Callback to parent
    onInspectionCreated(newInspection)
    
    // Dismiss sheet
    dismiss()
}
```

**Output:** New `Inspection` object passed back to `LMSHomeView`

---

### **Stage 2: Home View Update**
**View:** `LMSHomeView`

**Purpose:** Display list of inspections and handle navigation.

**Data Model:** `Inspection` (list)

**Navigation Setup:**
```swift
NavigationStack {
    // Inspection list...
}
.navigationDestination(for: Inspection.self) { inspection in
    InspectionDetailView(
        inspectionId: inspection.id,
        inspectionNumber: inspection.inspectionNumber,
        homeViewModel: viewModel
    )
}
.sheet(isPresented: $showCreateInspection) {
    CreateInspectionView { newInspection in
        // Handle navigation to detail
        // Option 1: Add to list and auto-navigate
        // Option 2: Refresh list
    }
}
```

**Key Points:**
- Uses `NavigationStack` with type-safe navigation
- `navigationDestination(for: Inspection.self)` creates navigation link
- Sheet presentation for `CreateInspectionView`

---

### **Stage 3: Inspection Detail Loading**
**View:** `InspectionDetailView`

**Purpose:** Load and display detailed inspection data with multiple tabs.

**Data Model Transformation:** `Inspection` → `InspectionDetail`

**Input:**
```swift
init(inspectionId: String, inspectionNumber: String, homeViewModel: LMSHomeViewModel? = nil)
```

**ViewModel:** `InspectionDetailViewModel`

**Data Structure:**
```swift
struct InspectionDetail: Identifiable, Equatable {
    let id: String
    let inspectionNumber: String
    let sections: [InspectionSection]  // ← Rich inspection form structure
    let orderQuantity: Int
    let actualCompletedQuantity: Int
    let aqlInspectionQuantity: Int
    let inspectedQuantity: Int
    let factoryName: String
}

struct InspectionSection: Identifiable, Equatable {
    let id: String
    let title: String
    let order: Int
    let itemCount: Int
    let fields: [InspectionField]  // ← Individual inspection checkpoints
}

struct InspectionField: Identifiable, Equatable {
    let id: String
    let label: String
    let type: FieldType  // text, number, select, photo
    let required: Bool
    let order: Int
}
```

**Photo Management:**
```swift
// In InspectionDetailViewModel
@Published var capturedPhotos: [String: [UIImage]] = [:]
//                              FieldId → Images
```

**Loading Logic:**
```swift
// In InspectionDetailViewModel
func loadInspectionDetail() async {
    isLoading = true
    defer { isLoading = false }
    
    do {
        // Transform Inspection basic info → InspectionDetail rich structure
        inspectionDetail = try await fetchInspectionDetailUseCase.execute(
            inspectionId: inspectionId
        )
        
        contentViewModel.autoExpandFirstSection()
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

**Key Points:**
- `InspectionDetail` is a **separate entity** with full inspection form structure
- Each `InspectionSection` contains multiple `InspectionField`
- `capturedPhotos` maps field IDs to arrays of captured images

---

### **Stage 4: Inspection Form Filling**
**View:** `InspectionDetailContentView`

**Purpose:** Display inspection sections and capture field photos.

**Data Model:** `InspectionDetail` + `capturedPhotos`

**Structure:**
```swift
struct InspectionDetailContentView: View {
    @ObservedObject var contentViewModel: InspectionDetailContentViewModel
    @State private var showFinalReport = false
    
    var body: some View {
        ScrollView {
            LazyVStack {
                // Display all sections
                ForEach(detail.sections.sorted(by: { $0.order < $1.order })) { section in
                    sectionView(for: section)
                }
                
                // Action buttons
                addCustomFieldButton()
                completeInspectionButton()  // ← Triggers navigation to FinalReportView
            }
        }
        .fullScreenCover(isPresented: $showFinalReport) {
            if let detail = contentViewModel.inspectionDetail {
                FinalReportView(
                    inspectionDetail: detail,
                    capturedPhotos: contentViewModel.capturedPhotos
                )
            }
        }
    }
}
```

**Photo Capture Flow:**
```swift
// 1. User taps camera icon on field
InspectionFieldItemView(
    fieldName: field.label,
    hasPhoto: contentViewModel.hasPhoto(for: field.id),
    images: contentViewModel.getImages(for: field.id),
    onCameraTap: { contentViewModel.openPhotoPicker(for: field.id) }
)

// 2. Opens camera/photo picker
.navigationDestination(isPresented: $viewModel.showCamera) {
    CameraView(source: .inspection) { images in
        viewModel.handlePhotoSelection(images)
    }
}

// 3. Photo saved to capturedPhotos dictionary
func savePhoto(_ image: UIImage, for fieldId: String) {
    if capturedPhotos[fieldId] == nil {
        capturedPhotos[fieldId] = []
    }
    capturedPhotos[fieldId]?.append(image)
}
```

**Complete Inspection Action:**
```swift
private func completeInspectionButton() -> some View {
    Button(action: {
        showFinalReport = true  // ← Triggers fullScreenCover
    }) {
        HStack {
            Image(systemName: "checkmark.circle.fill")
            Text("Hoàn tất kiểm tra")
        }
    }
}
```

**Key Data:**
- `inspectionDetail`: Complete inspection form structure
- `capturedPhotos`: Dictionary mapping field IDs to images

---

### **Stage 5: Final Report & PDF Generation**
**View:** `FinalReportView`

**Purpose:** Preview final report data and generate PDF.

**Data Model:** `InspectionDetail` + `capturedPhotos` → `PDFReportRequest`

**Initialization:**
```swift
struct FinalReportView: View {
    @StateObject private var viewModel: FinalReportViewModel
    
    init(
        inspectionDetail: InspectionDetail?,
        capturedPhotos: [String: [UIImage]]
    ) {
        _viewModel = StateObject(wrappedValue: FinalReportViewModel(
            inspectionDetail: inspectionDetail,
            capturedPhotos: capturedPhotos,
            generatePDFUseCase: Container.shared.resolve(GenerateHTMLPDFReportUseCase.self)!,
            sendEmailUseCase: Container.shared.resolve(SendEmailUseCase.self)!,
            uploadToFirestoreUseCase: Container.shared.resolve(UploadInspectionReportUseCase.self)!
        ))
    }
}
```

**PDF Generation with Builder Pattern:**
```swift
// In FinalReportViewModel
func generateAndPreviewPDF() async {
    guard let detail = inspectionDetail else { return }
    
    isGeneratingPDF = true
    defer { isGeneratingPDF = false }
    
    do {
        // Use Builder Pattern to create PDFReportRequest
        let request = try PDFReportRequestBuilder.withDefaults()
            .with(detail: detail)
            .with(images: capturedImages)  // Converted [String: [UIImage]] → [String: [Data]]
            .with(location: inspectionLocation)
            .build()
        
        // Generate PDF using request object
        let pdfData = try await generatePDFUseCase.execute(request: request)
        
        self.pdfData = pdfData
        isShowingPDFPreview = true
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

**Builder Pattern Details:**
```swift
// Domain/Entities/PDFReportRequestBuilder.swift
struct PDFReportRequestBuilder {
    private var inspectionDetail: InspectionDetail?
    private var capturedImages: [String: [Data]]?
    private var inspectorName: String?
    private var inspectionLocation: String
    
    // Factory method with defaults
    static func withDefaults() -> PDFReportRequestBuilder {
        PDFReportRequestBuilder(
            inspectionLocation: "",
            inspectorName: KeychainManager.getStoredUsername() ?? "Unknown"
        )
    }
    
    // Fluent API methods
    func with(detail: InspectionDetail) -> PDFReportRequestBuilder { ... }
    func with(images: [String: [Data]]) -> PDFReportRequestBuilder { ... }
    func with(location: String) -> PDFReportRequestBuilder { ... }
    
    // Build with validation
    func build() throws -> PDFReportRequest {
        guard let detail = inspectionDetail else {
            throw PDFReportBuilderError.missingInspectionDetail
        }
        guard let images = capturedImages else {
            throw PDFReportBuilderError.missingCapturedImages
        }
        
        return PDFReportRequest(
            inspectionDetail: detail,
            capturedImages: images,
            inspectorName: inspectorName ?? "Unknown",
            inspectionLocation: inspectionLocation
        )
    }
}
```

**PDFReportRequest Structure:**
```swift
struct PDFReportRequest: Equatable {
    let inspectionDetail: InspectionDetail
    let capturedImages: [String: [Data]]
    let inspectorName: String
    let inspectionLocation: String
}
```

---

### **Stage 6: PDF Use Case Execution**
**Use Case:** `GenerateHTMLPDFReportUseCase`

**Purpose:** Generate final PDF document from request data.

**Dual Interface:**
```swift
final class GenerateHTMLPDFReportUseCase {
    // NEW: Single parameter method (Builder Pattern)
    func execute(request: PDFReportRequest) async throws -> Data {
        try await execute(
            detail: request.inspectionDetail,
            images: request.capturedImages,
            inspectorName: request.inspectorName,
            location: request.inspectionLocation
        )
    }
    
    // LEGACY: Original 4-parameter method
    func execute(
        detail: InspectionDetail,
        images: [String: [Data]],
        inspectorName: String,
        location: String
    ) async throws -> Data {
        // Generate HTML content
        // Convert to PDF
        // Return PDF data
    }
}
```

**Output:** PDF file as `Data` object

---

## 📊 Data Model Transformation Summary

```
┌────────────────────────────────────────────────────────────────────┐
│                        Data Flow Timeline                          │
└────────────────────────────────────────────────────────────────────┘

1. CreateInspectionView
   │
   ├─► Inspection {
   │     id, inspectionNumber, companyName, productName,
   │     orderCode, factory, quantity, status
   │   }
   │
   ▼

2. LMSHomeView
   │
   ├─► Navigation: Pass inspectionId + inspectionNumber
   │
   ▼

3. InspectionDetailView
   │
   ├─► Load InspectionDetail {
   │     inspectionNumber, sections[], orderQuantity,
   │     actualCompletedQuantity, factoryName
   │   }
   │
   ├─► Capture Photos: [String: [UIImage]]
   │                    (fieldId → images)
   │
   ▼

4. InspectionDetailContentView
   │
   ├─► Button: "Hoàn tất kiểm tra"
   │
   ├─► Navigate to FinalReportView with:
   │     - InspectionDetail
   │     - capturedPhotos: [String: [UIImage]]
   │
   ▼

5. FinalReportView
   │
   ├─► Convert UIImage → Data
   │
   ├─► Build PDFReportRequest {
   │     inspectionDetail: InspectionDetail
   │     capturedImages: [String: [Data]]
   │     inspectorName: String (from Keychain)
   │     inspectionLocation: String
   │   }
   │
   ├─► Builder Pattern:
   │     PDFReportRequestBuilder.withDefaults()
   │       .with(detail: detail)
   │       .with(images: images)
   │       .with(location: location)
   │       .build()
   │
   ▼

6. GenerateHTMLPDFReportUseCase
   │
   ├─► execute(request: PDFReportRequest)
   │
   ├─► Generate HTML content
   │
   ├─► Convert HTML → PDF
   │
   └─► Return: Data (PDF bytes)
```

---

## 🔑 Key Models at Each Stage

### 1. **Inspection** (Basic Info)
- Used in: CreateInspectionView, LMSHomeView
- Purpose: Store basic inspection metadata
- Size: ~10 fields

### 2. **InspectionDetail** (Rich Structure)
- Used in: InspectionDetailView, FinalReportView
- Purpose: Complete inspection form with sections and fields
- Size: ~7 fields + nested arrays (sections → fields)

### 3. **capturedPhotos** (Photo Collection)
- Type: `[String: [UIImage]]`
- Used in: InspectionDetailViewModel, FinalReportView
- Purpose: Map field IDs to captured images

### 4. **PDFReportRequest** (Unified DTO)
- Used in: FinalReportView → GenerateHTMLPDFReportUseCase
- Purpose: Package all PDF generation data in one object
- Benefits:
  - ✅ Type-safe
  - ✅ Single parameter
  - ✅ Built-in validation
  - ✅ Automatic defaults from Keychain

---

## 🎨 Architecture Layer Mapping

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
├─────────────────────────────────────────────────────────────┤
│ LMSHomeView                                                  │
│   ↓                                                          │
│ CreateInspectionView                                         │
│   ↓                                                          │
│ InspectionDetailView                                         │
│   ├─► InspectionDetailViewModel                             │
│   └─► InspectionDetailContentView                           │
│        └─► InspectionDetailContentViewModel                 │
│            ↓                                                 │
│ FinalReportView                                              │
│   └─► FinalReportViewModel                                  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
├─────────────────────────────────────────────────────────────┤
│ Entities:                                                    │
│   - Inspection                                               │
│   - InspectionDetail                                         │
│   - PDFReportRequest                                         │
│   - PDFReportRequestBuilder                                  │
│                                                              │
│ Use Cases:                                                   │
│   - FetchInspectionDetailUseCase                            │
│   - GenerateHTMLPDFReportUseCase                            │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                             │
├─────────────────────────────────────────────────────────────┤
│ Services:                                                    │
│   - InspectionService                                        │
│   - PDFKitGeneratorService                                   │
│   - FirebaseStorageService                                   │
│                                                              │
│ Repositories:                                                │
│   - InspectionRepository                                     │
│   - FirestoreRepository                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Navigation Flow Implementation

### Type-Safe Navigation
```swift
// LMSHomeView.swift
NavigationStack {
    List(inspections) { inspection in
        Button(inspection.inspectionNumber) {
            // Programmatic navigation
        }
    }
}
.navigationDestination(for: Inspection.self) { inspection in
    InspectionDetailView(
        inspectionId: inspection.id,
        inspectionNumber: inspection.inspectionNumber
    )
}
```

### Sheet Presentation
```swift
// InspectionDetailContentView.swift
.fullScreenCover(isPresented: $showFinalReport) {
    if let detail = contentViewModel.inspectionDetail {
        FinalReportView(
            inspectionDetail: detail,
            capturedPhotos: contentViewModel.capturedPhotos
        )
    }
}
```

---

## 📝 Summary: Why This Workflow Works

### ✅ Clean Separation
- **Basic Info (Inspection)** → List/Navigation
- **Rich Data (InspectionDetail)** → Form/Editing
- **Final Package (PDFReportRequest)** → PDF Generation

### ✅ Builder Pattern Benefits
Before (4 parameters):
```swift
generatePDFUseCase.execute(
    detail: detail,
    images: images,
    inspectorName: KeychainManager.getStoredUsername() ?? "",
    location: location
)
```

After (1 parameter):
```swift
let request = try PDFReportRequestBuilder.withDefaults()
    .with(detail: detail)
    .with(images: images)
    .with(location: location)
    .build()

generatePDFUseCase.execute(request: request)
```

### ✅ Type Safety
- Inspection type for navigation
- InspectionDetail for detailed form
- PDFReportRequest for PDF generation
- Compile-time validation

### ✅ Clean Architecture
- Presentation uses Domain entities
- Domain defines interfaces
- Data implements repositories
- No layer violations

---

## 🚀 Quick Reference

| Stage | View | Input | Output |
|-------|------|-------|--------|
| 1 | CreateInspectionView | User input | Inspection |
| 2 | LMSHomeView | Inspection list | inspectionId + number |
| 3 | InspectionDetailView | inspectionId | InspectionDetail + photos |
| 4 | InspectionDetailContentView | InspectionDetail | Navigation trigger |
| 5 | FinalReportView | InspectionDetail + photos | PDFReportRequest |
| 6 | GenerateHTMLPDFReportUseCase | PDFReportRequest | PDF Data |

---

## 📚 Related Documentation

- [Architecture Guide](/.github/instructions/architecture.instructions.md)
- [Alternative Approaches Analysis](ALTERNATIVE_APPROACHES_PDF_REFACTORING.md)
- [PDF Refactoring Quick Reference](PDF_REFACTORING_QUICK_REFERENCE.md)

---

**Document Version:** 1.0  
**Last Updated:** January 2026  
**Author:** GitHub Copilot
