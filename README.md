# report_lms — QA Inspection Management App

## Business Overview

**report_lms** is a mobile application for quality assurance inspectors in the garment/manufacturing industry. It digitises the end-to-end inspection workflow — from scheduling and conducting inspections on the factory floor, to capturing photo evidence and generating final PDF reports delivered to clients.

The app targets field inspectors who work on-site at Vietnamese factories and need an offline-capable, structured tool to replace paper-based inspection sheets.

---

## Features

### Authentication
- Email/password login via Firebase Auth
- Password recovery flow
- Persistent session management

### Home — Tab Navigation
Three tabs driven by `InspectionStatus`:

| Tab | Status filter | Purpose |
|-----|--------------|---------|
| Kế hoạch (Plan) | `.plan` | Inspections scheduled but not yet started |
| Trong tiến trình (In Progress) | `.inProgress` | Inspections currently being conducted |
| Báo cáo (Report) | `.completed` | Completed inspections and reports |

### Inspection Planning
- View inspections grouped by week
- Pull-to-refresh and auto-reload via Firestore cache notification
- Create new inspection with product name, product code, order code, quantity, inspection type, factory, production unit

### Inspection Detail
- Multi-section form reflecting the physical inspection checklist
- Fields support: text input, numeric input, checkbox, photo capture
- Per-field validation with error indicators
- Real-time save to Firestore on field change

### Photo Capture
- In-app camera for capturing inspection evidence
- Multiple photos per field
- Upload to Firebase Storage, URL stored on field model
- Photo review and retake flow

### Error / Defect Reporting
- Log defects with severity level (`SeverityLevel`) and defect type (`DefectType`)
- Photo evidence attached per defect
- Separate camera flow for error capture (`ErrorHomeView`)

### Final Report Generation
- Generates a PDF from inspection data using `PDFKit`
- HTML template rendered to PDF via `GenerateHTMLPDFReportUseCase`
- Report recipients configurable (`FinalReportRecipient`)
- Report status tracked (`FinalReportStatus`)

### Orders
- View orders linked to inspections via `OrdersView`
- Managed through `FirestoreService`

### Side Menu
- Profile, Settings, Orders, Logout navigation

---

## Architecture

The app follows **Clean Architecture** with MVVM and a strict 3-layer separation:

```
Presentation   (SwiftUI Views + ViewModels)
      │  protocols only
Domain         (Entities + Use Cases)
      │  protocols only
Data           (Repositories + Services + Firebase)
```

**Key patterns:**
- **MVVM** — `@Published` + `ObservableObject` for state, `@StateObject`/`@ObservedObject` for ownership
- **Combine** — reactive data flow between ViewModel and View
- **Repository pattern** — `InspectionStorageServiceType` abstracts Firestore from domain
- **Dependency Injection** — custom `Container` (Swinject-style), resolved at call sites
- **Notification-based cache sync** — `NotificationCenter.post(.inspectionCacheDidLoad)` triggers UI reload after Firestore fetch completes

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Reactive | Combine |
| Backend | Firebase Firestore |
| Auth | Firebase Auth |
| Media Storage | Firebase Storage |
| PDF | PDFKit |
| DI | Custom `Container` |

---

## Domain Models

| Model | Description |
|-------|------------|
| `Inspection` | Core entity — inspectionNumber, companyName, productName, status, sections |
| `InspectionStatus` | `.plan` · `.inProgress` · `.error` · `.completed` · `.cancelled` |
| `InspectionSection` | Grouped set of fields within an inspection |
| `InspectionField` | Single form field — text, photo, checkbox, or number |
| `ErrorItem` | Defect record with severity and type |
| `WeekSection` | UI grouping of inspections by calendar week |
| `FinalReportStatus` | Status of the generated PDF report |
| `FinalReportRecipient` | Report delivery target |

---

## Module Structure

```
report_lms/
├── Sources/
│   ├── Presentation/
│   │   └── Modules/
│   │       ├── Home/
│   │       │   ├── Plan/               # PlanLMSHomeView + PlanLMSHomeViewModel
│   │       │   ├── Progress/           # LMSProgressView + ProgressViewModel
│   │       │   └── ErrorHome/          # ErrorHomeView (legacy error tab)
│   │       ├── CreateInspectionView/   # New inspection form
│   │       ├── InspectionDetail/       # Detail form, validation, final report
│   │       ├── Camera/                 # Photo capture
│   │       ├── Orders/                 # Order list
│   │       ├── Login/                  # Auth screens
│   │       └── Menu/                   # Side navigation
│   ├── Domain/
│   │   ├── Entities/                   # Inspection, InspectionStatus, WeekSection, …
│   │   ├── UseCases/                   # GroupInspectionsByWeekUseCase, GenerateHTMLPDFReportUseCase, …
│   │   └── Repositories/              # Protocol definitions
│   ├── Data/
│   │   ├── Services/                   # FirestoreInspectionStorageService, FirestoreService
│   │   ├── Models/                     # InspectionModel (Codable DTOs)
│   │   └── Repositories/              # Protocol implementations
│   └── DI/
│       └── Container.swift             # Dependency registration
└── README.md
```

---

## Inspection Number Format

Generated at creation time: `INS-yyyyMMHHmmss`

Example: `INS-202604061523045` → year 2026, month 04, hour 15, minute 23, second 45

---

## Data Flow — Firestore Cache

```
App Launch
  └─ storageService.loadCache()     # Fetch all inspections from Firestore
        └─ NotificationCenter.post(.inspectionCacheDidLoad)
              └─ PlanLMSHomeViewModel.loadInspections()   # filter .plan
              └─ ProgressViewModel.loadInspections()      # filter .inProgress
```

ViewModels start with `isLoading = true` and only dismiss loading after `.inspectionCacheDidLoad` fires, preventing an empty-state flash during the initial Firestore fetch.
