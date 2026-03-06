# Workflow Diagram - Visual Data Flow
## report_lms Application

---

## 📊 Complete Workflow Visualization

```mermaid
flowchart TB
    Start([User Opens App]) --> Home[LMSHomeView]
    
    Home -->|Tap "Tạo kiểm tra"| Create[CreateInspectionView]
    Home -->|Select Inspection| Detail[InspectionDetailView]
    
    Create -->|Fill Form| CreateForm{User Input}
    CreateForm -->|Submit| CreateInspection[Create Inspection Object]
    CreateInspection --> Callback[onInspectionCreated callback]
    Callback --> Home
    
    Detail -->|Load Data| LoadDetail[Load InspectionDetail]
    LoadDetail --> DetailTabs{Display Tabs}
    
    DetailTabs --> Tab1[Tab: Kiểm tra]
    DetailTabs --> Tab2[Tab: Lỗi]
    DetailTabs --> Tab3[Tab: Thông tin đơn hàng]
    
    Tab1 --> Sections[Display Sections & Fields]
    Sections -->|Tap Camera Icon| Camera[CameraView]
    Camera -->|Capture| Photos[Save to capturedPhotos]
    Photos --> Sections
    
    Sections -->|Tap "Hoàn tất kiểm tra"| Final[FinalReportView]
    
    Final -->|Generate PDF| BuildRequest[PDFReportRequestBuilder]
    BuildRequest -->|.withDefaults| Builder1[Set Inspector Name]
    Builder1 -->|.with detail:| Builder2[Add InspectionDetail]
    Builder2 -->|.with images:| Builder3[Add Captured Images]
    Builder3 -->|.with location:| Builder4[Add Location]
    Builder4 -->|.build| Request[PDFReportRequest]
    
    Request --> UseCase[GenerateHTMLPDFReportUseCase]
    UseCase --> GenerateHTML[Generate HTML Content]
    GenerateHTML --> ConvertPDF[Convert HTML to PDF]
    ConvertPDF --> PDFData[PDF Data]
    
    PDFData --> Actions{User Action}
    Actions -->|Preview| Preview[Display PDF Preview]
    Actions -->|Send Email| Email[Send via Mail]
    Actions -->|Upload| Firestore[Upload to Firestore]
    
    Preview --> End([Done])
    Email --> End
    Firestore --> End

    style Home fill:#e1f5ff
    style Create fill:#fff4e1
    style Detail fill:#e8f5e9
    style Final fill:#fce4ec
    style Request fill:#f3e5f5
    style UseCase fill:#e0f2f1
    style PDFData fill:#fff9c4
```

---

## 🔄 Data Model Transformation Flow

```mermaid
graph LR
    A[Inspection<br/>Basic Info] -->|inspectionId| B[InspectionDetail<br/>Rich Structure]
    B -->|+ capturedPhotos| C[Combined Data]
    C -->|Builder Pattern| D[PDFReportRequest<br/>Unified DTO]
    D -->|Use Case| E[PDF Data<br/>Final Output]

    style A fill:#bbdefb
    style B fill:#c8e6c9
    style C fill:#fff9c4
    style D fill:#f8bbd0
    style E fill:#ffccbc
```

---

## 🏗️ Clean Architecture Layers

```mermaid
graph TB
    subgraph Presentation["🎨 Presentation Layer"]
        V1[LMSHomeView]
        V2[CreateInspectionView]
        V3[InspectionDetailView]
        V4[InspectionDetailContentView]
        V5[FinalReportView]
        
        VM1[InspectionDetailViewModel]
        VM2[InspectionDetailContentViewModel]
        VM3[FinalReportViewModel]
    end
    
    subgraph Domain["⚙️ Domain Layer"]
        E1[Inspection Entity]
        E2[InspectionDetail Entity]
        E3[PDFReportRequest]
        E4[PDFReportRequestBuilder]
        
        UC1[FetchInspectionDetailUseCase]
        UC2[GenerateHTMLPDFReportUseCase]
        
        R1[InspectionRepositoryType]
    end
    
    subgraph Data["💾 Data Layer"]
        S1[InspectionService]
        S2[PDFKitGeneratorService]
        S3[FirestoreService]
        
        R2[InspectionRepository]
    end
    
    V3 --> VM1
    V4 --> VM2
    V5 --> VM3
    
    VM1 --> UC1
    VM3 --> UC2
    
    UC1 --> R1
    UC2 --> R1
    
    R1 -.implements.- R2
    R2 --> S1
    R2 --> S2
    R2 --> S3
    
    E1 -.used by.- V1
    E2 -.used by.- V3
    E3 -.used by.- VM3

    style Presentation fill:#e3f2fd
    style Domain fill:#f3e5f5
    style Data fill:#e8f5e9
```

---

## 📸 Photo Capture Flow

```mermaid
sequenceDiagram
    participant User
    participant Field as InspectionFieldItemView
    participant VM as InspectionDetailViewModel
    participant Camera as CameraView
    participant Storage as capturedPhotos Dictionary

    User->>Field: Tap Camera Icon
    Field->>VM: openPhotoPicker(fieldId)
    VM->>VM: selectedFieldId = fieldId
    VM->>VM: showCamera = true
    
    Note over Camera: NavigationDestination triggered
    
    VM->>Camera: Navigate to CameraView
    User->>Camera: Capture Photos
    Camera->>VM: Return [UIImage]
    VM->>VM: handlePhotoSelection(images)
    
    loop For each image
        VM->>Storage: savePhoto(image, fieldId)
        Storage-->>VM: Photo saved
    end
    
    VM->>Field: Update hasPhoto status
    Field-->>User: Display photo count badge
```

---

## 🔨 Builder Pattern Workflow

```mermaid
flowchart LR
    Start([Start PDF Generation]) --> Check{Has<br/>InspectionDetail?}
    Check -->|No| Error[Show Error:<br/>No Data]
    Check -->|Yes| Builder[PDFReportRequestBuilder]
    
    Builder --> Default[.withDefaults<br/>Get Username from Keychain]
    Default --> Detail[.with detail:<br/>InspectionDetail]
    Detail --> Images[.with images:<br/>Convert UIImage to Data]
    Images --> Location[.with location:<br/>User Input]
    Location --> Build[.build]
    
    Build --> Validate{Validation}
    Validate -->|Missing Detail| BuildError1[Throw:<br/>missingInspectionDetail]
    Validate -->|Missing Images| BuildError2[Throw:<br/>missingCapturedImages]
    Validate -->|Success| Request[PDFReportRequest]
    
    Request --> UseCase[execute request:]
    UseCase --> PDF[PDF Data]
    PDF --> End([PDF Ready])
    
    Error --> EndError([Done])
    BuildError1 --> EndError
    BuildError2 --> EndError

    style Builder fill:#e1bee7
    style Request fill:#c5e1a5
    style PDF fill:#fff59d
```

---

## 🗂️ Data Structure Relationships

```mermaid
erDiagram
    Inspection ||--o{ InspectionDetail : "transforms to"
    InspectionDetail ||--|{ InspectionSection : contains
    InspectionSection ||--|{ InspectionField : contains
    InspectionField ||--o{ Photo : "can have"
    
    InspectionDetail ||--|| PDFReportRequest : "included in"
    Photo ||--|| PDFReportRequest : "included in"
    PDFReportRequest ||--|| PDFData : "generates"
    
    Inspection {
        string id
        string inspectionNumber
        string companyName
        string productName
        string orderCode
        string factory
        int quantity
        enum status
    }
    
    InspectionDetail {
        string id
        string inspectionNumber
        array sections
        int orderQuantity
        int actualCompletedQuantity
        string factoryName
    }
    
    InspectionSection {
        string id
        string title
        int order
        int itemCount
        array fields
    }
    
    InspectionField {
        string id
        string label
        enum type
        bool required
        int order
    }
    
    PDFReportRequest {
        InspectionDetail inspectionDetail
        dictionary capturedImages
        string inspectorName
        string inspectionLocation
    }
```

---

## 🎯 Navigation Types

```mermaid
graph TB
    subgraph Nav["SwiftUI Navigation"]
        NS[NavigationStack]
        ND[navigationDestination]
        Sheet[.sheet]
        Full[.fullScreenCover]
    end
    
    subgraph Views["View Transitions"]
        Home[LMSHomeView]
        Create[CreateInspectionView]
        Detail[InspectionDetailView]
        Camera[CameraView]
        Final[FinalReportView]
    end
    
    NS --> Home
    Home --> Sheet
    Sheet --> Create
    
    Home --> ND
    ND --> Detail
    
    Detail --> ND
    ND --> Camera
    
    Detail --> Full
    Full --> Final

    style NS fill:#b3e5fc
    style ND fill:#c5cae9
    style Sheet fill:#f8bbd0
    style Full fill:#ffccbc
```

---

## 📦 PDFReportRequest Properties

```mermaid
classDiagram
    class PDFReportRequest {
        +InspectionDetail inspectionDetail
        +Dictionary~String, Array~Data~~ capturedImages
        +String inspectorName
        +String inspectionLocation
        
        +init(inspectionDetail, capturedImages, inspectorName, inspectionLocation)
    }
    
    class PDFReportRequestBuilder {
        -InspectionDetail? inspectionDetail
        -Dictionary? capturedImages
        -String? inspectorName
        -String inspectionLocation
        
        +withDefaults()$ PDFReportRequestBuilder
        +with(detail: InspectionDetail) PDFReportRequestBuilder
        +with(images: Dictionary) PDFReportRequestBuilder
        +with(location: String) PDFReportRequestBuilder
        +build() PDFReportRequest
    }
    
    class InspectionDetail {
        +String id
        +String inspectionNumber
        +Array~InspectionSection~ sections
        +Int orderQuantity
        +String factoryName
    }
    
    PDFReportRequestBuilder ..> PDFReportRequest : creates
    PDFReportRequest --> InspectionDetail : contains
```

---

## 🧪 State Management Flow

```mermaid
stateDiagram-v2
    [*] --> Loading: Load Inspection
    Loading --> Loaded: Data Fetched
    Loading --> Error: Fetch Failed
    
    Loaded --> CapturingPhoto: Tap Camera
    CapturingPhoto --> Loaded: Photo Saved
    
    Loaded --> GeneratingPDF: Tap Complete
    GeneratingPDF --> PDFReady: Success
    GeneratingPDF --> PDFError: Failed
    
    PDFReady --> Previewing: Tap Preview
    PDFReady --> Sending: Tap Send Email
    PDFReady --> Uploading: Tap Upload
    
    Previewing --> [*]
    Sending --> [*]
    Uploading --> [*]
    Error --> [*]: Dismiss
    PDFError --> [*]: Dismiss
```

---

## 🔐 KeychainManager Integration

```mermaid
flowchart LR
    A[User Logs In] --> B[Save to Keychain]
    B --> C[KeychainManager]
    
    D[PDF Generation] --> E[Builder.withDefaults]
    E --> F[KeychainManager.getStoredUsername]
    F --> G{Username Found?}
    
    G -->|Yes| H[Use Username]
    G -->|No| I[Use 'Unknown']
    
    H --> J[PDFReportRequest]
    I --> J
    
    C -.stored.- F

    style C fill:#ffecb3
    style J fill:#c5e1a5
```

---

## 📊 Layer Communication Summary

```mermaid
graph TB
    subgraph UI["User Interface"]
        Views[SwiftUI Views]
    end
    
    subgraph VM["ViewModels"]
        ViewModels[@Published Properties<br/>@MainActor]
    end
    
    subgraph UC["Use Cases"]
        UseCases[Business Logic<br/>async/await]
    end
    
    subgraph Repo["Repositories"]
        Protocols[Protocol Definitions]
        Impl[Implementations]
    end
    
    subgraph Services["Services"]
        API[API Calls]
        Storage[Local Storage]
        PDF[PDF Generation]
    end
    
    Views -->|Observe| ViewModels
    ViewModels -->|Call| UseCases
    UseCases -->|Depend on| Protocols
    Protocols -->|Implemented by| Impl
    Impl -->|Use| API
    Impl -->|Use| Storage
    Impl -->|Use| PDF
    
    style UI fill:#e1f5fe
    style VM fill:#f3e5f5
    style UC fill:#e8f5e9
    style Repo fill:#fff9c4
    style Services fill:#ffccbc
```

---

## 🎬 Complete User Journey

```mermaid
journey
    title Inspection & PDF Generation Journey
    section Create Inspection
      Open App: 5: User
      Tap Create: 5: User
      Fill Form: 3: User
      Submit: 5: User
    section Perform Inspection
      Open Detail: 5: User
      View Sections: 5: User
      Capture Photos: 4: User
      Fill Fields: 3: User
    section Complete
      Tap Complete: 5: User
      Review Report: 5: User
      Generate PDF: 4: System
      Preview PDF: 5: User
    section Finish
      Send Email: 5: User
      Upload Report: 5: System
```

---

## 🚦 Error Handling Flow

```mermaid
flowchart TB
    Start([User Action]) --> Try{Try Operation}
    
    Try -->|Success| Success[Display UI]
    Try -->|Error| Catch[Catch Error]
    
    Catch --> Type{Error Type}
    
    Type -->|Network| Net[Show Network Error]
    Type -->|Validation| Val[Show Validation Error]
    Type -->|Builder| Build[Show Builder Error]
    Type -->|Unknown| Unk[Show Generic Error]
    
    Net --> Retry[Show Retry Button]
    Val --> Fix[Show Fix Instructions]
    Build --> Check[Show Missing Fields]
    Unk --> Log[Log Error]
    
    Retry --> Start
    Fix --> End([User Fixes])
    Check --> End
    Log --> End
    Success --> End

    style Catch fill:#ffcdd2
    style Type fill:#fff9c4
    style Success fill:#c8e6c9
```

---

## 📝 Quick Legend

| Symbol | Meaning |
|--------|---------|
| 🎨 | Presentation Layer |
| ⚙️ | Domain Layer |
| 💾 | Data Layer |
| 📸 | Photo/Image Related |
| 🔨 | Builder Pattern |
| 🔐 | Authentication/Security |
| 🚦 | Error Handling |
| 🎯 | Navigation |

---

## 🔗 Related Documents

- [Detailed Workflow Analysis](WORKFLOW_DATA_FLOW.md)
- [Architecture Guide](/.github/instructions/architecture.instructions.md)
- [Alternative Approaches](ALTERNATIVE_APPROACHES_PDF_REFACTORING.md)

---

**Document Version:** 1.0  
**Last Updated:** January 2026  
**Author:** GitHub Copilot
