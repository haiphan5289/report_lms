# Inspection Creation Workflow Documentation

## 📋 Tổng quan

Tài liệu này mô tả chi tiết workflow tạo mới một Inspection và cập nhật danh sách hiển thị trong ứng dụng.

## 🏗️ Kiến trúc Clean Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌────────────────┐              ┌──────────────────┐       │
│  │CreateInspection│              │  PlanLMSHomeView │       │
│  │     View       │──callback──→ │   & ViewModel    │       │
│  └────────────────┘              └──────────────────┘       │
│         │                                  │                 │
│         ↓                                  ↓                 │
│  ┌────────────────┐              ┌──────────────────┐       │
│  │CreateInspection│              │FetchInspections  │       │
│  │   ViewModel    │              │    UseCase       │       │
│  └────────────────┘              └──────────────────┘       │
└─────────────────────────────────────────────────────────────┘
         │                                  │
         ↓                                  ↓
┌─────────────────────────────────────────────────────────────┐
│                      Domain Layer                            │
│  ┌────────────────┐              ┌──────────────────┐       │
│  │CreateInspection│              │  Inspection      │       │
│  │    UseCase     │              │    Entity        │       │
│  └────────────────┘              └──────────────────┘       │
└─────────────────────────────────────────────────────────────┘
         │                                  │
         ↓                                  ↓
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                             │
│  ┌─────────────────────────────────────────────────┐        │
│  │         InspectionRepository (SINGLETON)         │        │
│  │  • Quản lý Combine Publisher                     │        │
│  │  • Đồng bộ data giữa các ViewModel               │        │
│  └─────────────────────────────────────────────────┘        │
│         │                                  │                 │
│         ↓                                  ↓                 │
│  ┌────────────────┐              ┌──────────────────┐       │
│  │createInspection│              │  fetchInspections│       │
│  └────────────────┘              └──────────────────┘       │
│         │                                  │                 │
│         ↓                                  ↓                 │
│  ┌─────────────────────────────────────────────────┐        │
│  │    InspectionService (SINGLETON - IN-MEMORY)     │        │
│  │    private var inspections: [InspectionModel]    │  ◄──── STORAGE
│  └─────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## 🔄 Workflow Chi Tiết

### Bước 1: User Tạo Inspection

**File:** `CreateInspectionView.swift`

```swift
// Line 98-107: Button tạo inspection
LMSButton("Tạo kiểm tra") {
    Task {
        await viewModel.createInspection()  // Gọi ViewModel
    }
}
```

### Bước 2: ViewModel Validate và Tạo

**File:** `CreateInspectionViewModel.swift`

```swift
// Line 125-164: Xử lý tạo inspection
func createInspection() async {
    guard validateInputs() else { return }
    
    let inspection = try await createInspectionUseCase.execute(...)
    createdInspection = inspection  // Cập nhật @Published property
}
```

### Bước 3: UseCase Tạo Entity

**File:** `CreateInspectionUseCase.swift`

```swift
// Line 17-36: Tạo Inspection entity và gọi repository
func execute(...) async throws -> Inspection {
    let inspection = Inspection(...)
    return try await repository.createInspection(inspection)
}
```

### Bước 4: Repository Update Publisher

**File:** `InspectionRepository.swift`

```swift
// Line 23-34: Repository xử lý và publish update
func createInspection(_ inspection: Inspection) async throws -> Inspection {
    let model = InspectionModel.fromEntity(inspection)
    let responseModel = try await service.createInspection(model)
    let newInspection = responseModel.toEntity()
    
    // 🔥 KEY: Notify tất cả subscribers
    var currentInspections = inspectionsSubject.value
    currentInspections.insert(newInspection, at: 0)
    inspectionsSubject.send(currentInspections)  // ◄─── PUBLISH UPDATE
    
    return newInspection
}
```

### Bước 5: Service Lưu Vào Memory

**File:** `InspectionService.swift`

```swift
final class InspectionService: InspectionServiceType {
    // 🔥 KEY: In-memory storage
    private var inspections: [InspectionModel] = []  // ◄─── LINE 12: STORAGE
    
    // Line 11-24: Lưu inspection vào array
    func createInspection(_ model: InspectionModel) async throws -> InspectionModel {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // 🔥 LINE 20: UPDATE inspections array
        inspections.insert(model, at: 0)  // ◄─── THÊM VÀO ĐẦU MẢNG
        
        return model
    }
    
    // Line 26-29: Trả về danh sách đã lưu
    func getInspections() async throws -> [InspectionModel] {
        return inspections  // ◄─── TRẢ VỀ TỪ MEMORY
    }
}
```

### Bước 6: View Dismiss và Callback

**File:** `CreateInspectionView.swift`

```swift
// Line 57-68: Lắng nghe thay đổi và dismiss
.onChange(of: viewModel.createdInspection) { _, newInspection in
    if let inspection = newInspection {
        onInspectionCreated?(inspection)  // Gọi callback
        dismiss()  // Pop view
    }
}
```

### Bước 7: HomeView Nhận Callback

**File:** `PlanLMSHomeView.swift`

```swift
// Line 40-45: Nhận callback từ CreateInspectionView
CreateInspectionView(viewModel: createViewModel) { createdInspection in
    viewModel.addNewInspection(createdInspection)
}
```

### Bước 8: Publisher Tự Động Update UI

**File:** `PlanLMSHomeViewModel.swift`

```swift
// Line 111-126: Subscription tự động nhận update từ repository
private func setupSubscriptions() {
    repository.inspectionsPublisher  // ◄─── LẮNG NGHE PUBLISHER
        .receive(on: DispatchQueue.main)
        .sink { [weak self] inspections in
            guard let self = self else { return }
            let sections = self.groupInspectionsByWeekUseCase.execute(inspections)
            self.weeklyInspections = sections  // ◄─── TỰ ĐỘNG CẬP NHẬT UI
        }
        .store(in: &cancellables)
}
```

## 🔑 Các Điểm Quan Trọng

### 1. InspectionService Storage

**File:** `report_lms/Sources/Data/Services/InspectionService.swift`

```swift
// LINE 12: Khai báo storage
private var inspections: [InspectionModel] = []

// LINE 20: Cập nhật storage khi tạo mới
inspections.insert(model, at: 0)  // Thêm vào đầu mảng

// LINE 28: Trả về storage khi fetch
return inspections
```

### 2. Singleton Pattern trong Container

**File:** `Container.swift`

```swift
// Line 35-43: Service và Repository là SINGLETON
private func registerDependencies() {
    // SINGLETON: Tất cả ViewModels dùng chung 1 instance
    let inspectionService = InspectionService()
    registerSingleton(InspectionServiceType.self, instance: inspectionService)
    
    let inspectionRepository = InspectionRepository(service: inspectionService)
    registerSingleton(InspectionRepositoryType.self, instance: inspectionRepository)
}
```

**Tại sao cần Singleton?**
- ✅ Đảm bảo tất cả ViewModels dùng chung 1 instance Repository
- ✅ Publisher hoạt động đồng bộ giữa các màn hình
- ✅ Data được chia sẻ giữa CreateViewModel và HomeViewModel
- ❌ Nếu không dùng Singleton: Mỗi ViewModel có instance riêng → data không đồng bộ

## 📊 Data Flow Diagram

```
┌──────────────────┐
│  User Tap Button │
└────────┬─────────┘
         ↓
┌──────────────────────────────────────┐
│  CreateInspectionViewModel           │
│  • Validate inputs                   │
│  • Call createInspectionUseCase      │
└────────┬─────────────────────────────┘
         ↓
┌──────────────────────────────────────┐
│  CreateInspectionUseCase             │
│  • Create Inspection entity          │
│  • Call repository.createInspection  │
└────────┬─────────────────────────────┘
         ↓
┌──────────────────────────────────────┐
│  InspectionRepository (SINGLETON)    │
│  • Call service.createInspection     │
│  • Update inspectionsSubject         │
│  • Publish to all subscribers        │
└────────┬─────────────────────────────┘
         ↓
┌──────────────────────────────────────┐
│  InspectionService (SINGLETON)       │
│  • inspections.insert(model, at: 0)  │ ◄─── LINE 20: UPDATE
│  • Store in memory array             │
└────────┬─────────────────────────────┘
         │
         ├─────────────────────────────────┐
         ↓                                 ↓
┌────────────────────┐         ┌──────────────────────┐
│ CreateInspection   │         │ PlanLMSHomeViewModel │
│ createdInspection  │         │ • Publisher fires    │
│ → onChange fires   │         │ • weeklyInspections  │
│ → Callback         │         │   updated           │
│ → dismiss()        │         │ • UI refreshes      │
└────────────────────┘         └──────────────────────┘
```

## 🐛 Debugging

Khi chạy ứng dụng, console sẽ hiển thị logs theo thứ tự:

```
1. 🔵 [CreateInspectionView] Button tapped
2. 🟡 [CreateInspectionViewModel] createInspection() called
3. 🟡 [CreateInspectionViewModel] Validation passed
4. 🟡 [CreateInspectionViewModel] Calling createInspectionUseCase...
5. 📦 [InspectionRepository] createInspection() called
6. 🔧 [InspectionService] createInspection() called
7. 🔧 [InspectionService] Stored inspection, total count: 1  ◄─── LINE 21
8. 📦 [InspectionRepository] Sending update to inspectionsSubject...
9. 🔷 [PlanLMSHomeViewModel] ===== PUBLISHER FIRED =====
10. 🔷 [PlanLMSHomeViewModel] Publisher received 1 inspections
11. 🔷 [PlanLMSHomeViewModel] weeklyInspections updated
12. 🟢 [CreateInspectionView] onChange triggered
13. 🟢 [CreateInspectionView] Dismissing view
14. ✅ UI UPDATED!
```

## 📁 File Structure

```
report_lms/
├── Sources/
│   ├── Data/
│   │   ├── Services/
│   │   │   └── InspectionService.swift          ◄─── LINE 12, 20: Storage
│   │   └── Repositories/
│   │       └── InspectionRepository.swift       ◄─── LINE 29-31: Publisher
│   ├── Domain/
│   │   ├── Entities/
│   │   │   └── Inspection.swift
│   │   └── UseCases/
│   │       ├── CreateInspectionUseCase.swift
│   │       └── FetchInspectionsUseCase.swift
│   ├── Presentation/
│   │   └── Modules/
│   │       ├── CreateInspectionView/
│   │       │   ├── CreateInspectionView.swift   ◄─── LINE 57: onChange
│   │       │   └── CreateInspectionViewModel.swift
│   │       └── Home/
│   │           ├── PlanLMSHomeView.swift        ◄─── LINE 40: Callback
│   │           └── PlanLMSHomeViewModel.swift   ◄─── LINE 112: Subscription
│   └── DI/
│       └── Container.swift                      ◄─── LINE 35-40: Singletons
```

## ✅ Checklist Kiểm Tra

Nếu UI không update, kiểm tra theo thứ tự:

- [ ] InspectionService có `private var inspections` array? (Line 12)
- [ ] createInspection() có `inspections.insert(model, at: 0)`? (Line 20)
- [ ] getInspections() có return `inspections`? (Line 28)
- [ ] Container có đăng ký Service/Repository là Singleton? (Line 35-40)
- [ ] Repository có call `inspectionsSubject.send()`? (Line 31)
- [ ] ViewModel có setup subscription? (Line 112-126)
- [ ] Console có hiển thị log `🔷 PUBLISHER FIRED`?

## 🎯 Key Takeaways

1. **InspectionService.inspections** được update tại **LINE 20**: `inspections.insert(model, at: 0)`
2. **Singleton Pattern** đảm bảo tất cả components dùng chung 1 instance
3. **Combine Publisher** tự động đồng bộ data giữa các màn hình
4. **Clean Architecture** tách biệt rõ ràng giữa các layer
5. **Reactive Programming** với @Published và Publisher/Subscriber pattern

## 📞 Support

Nếu có vấn đề, kiểm tra console logs để xác định bước nào bị lỗi trong workflow.

---

**Last Updated:** January 28, 2026
**Version:** 1.0.0
