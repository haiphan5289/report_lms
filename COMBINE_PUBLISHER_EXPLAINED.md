# Giải Thích: inspectionsSubject.send() và Combine Publisher

## 📚 Kiến Thức Cơ Bản

### 1. Combine Framework là gì?

Combine là framework của Apple cho **Reactive Programming** (lập trình phản ứng):
- Xử lý **async events** (sự kiện bất đồng bộ)
- Theo dõi **data changes** (thay đổi dữ liệu)
- Tự động **propagate updates** (lan truyền cập nhật)

```
Tưởng tượng như một đài phát thanh:
- Publisher (Đài phát thanh) = Phát sóng
- Subscriber (Người nghe) = Nghe radio
- Khi đài phát tin mới → Tất cả người nghe đều nhận được
```

## 🔍 CurrentValueSubject

### Trong InspectionRepository:

```swift
// Line 13: Khai báo Subject
private let inspectionsSubject = CurrentValueSubject<[Inspection], Never>([])
```

### Phân tích:

```swift
CurrentValueSubject<[Inspection], Never>([])
        │             │           │      │
        │             │           │      └─ Initial Value (giá trị khởi tạo)
        │             │           │         = [] (mảng rỗng)
        │             │           │
        │             │           └─ Error Type = Never
        │             │              (không bao giờ throw error)
        │             │
        │             └─ Output Type = [Inspection]
        │                (kiểu dữ liệu được publish)
        │
        └─ CurrentValueSubject
           (một loại Publisher đặc biệt)
```

### CurrentValueSubject vs PassthroughSubject

| CurrentValueSubject | PassthroughSubject |
|-------------------|-------------------|
| ✅ Lưu giá trị hiện tại | ❌ Không lưu giá trị |
| ✅ Subscriber mới nhận giá trị ngay | ❌ Subscriber chỉ nhận giá trị mới |
| ✅ Có `.value` property | ❌ Không có `.value` |
| 📦 Dùng cho: State management | 📣 Dùng cho: Events, Actions |

**Ví dụ:**
```swift
// CurrentValueSubject
let subject = CurrentValueSubject<Int, Never>(0)
subject.send(1)
subject.send(2)
print(subject.value) // Output: 2 ← Có thể lấy giá trị hiện tại

subject.sink { value in
    print("Received: \(value)")
} // Output: "Received: 2" ← Subscriber mới nhận ngay giá trị hiện tại

// PassthroughSubject
let passthrough = PassthroughSubject<Int, Never>()
passthrough.send(1)
passthrough.send(2)
// print(passthrough.value) ← ERROR: Không có .value property

passthrough.sink { value in
    print("Received: \(value)")
} // Không output gì ← Subscriber mới không nhận giá trị cũ
```

## 🎯 Trong InspectionRepository

### Code Đầy Đủ:

```swift
final class InspectionRepository: InspectionRepositoryType {
    // STEP 1: Khai báo Subject (Private)
    private let inspectionsSubject = CurrentValueSubject<[Inspection], Never>([])
    
    // STEP 2: Expose Publisher (Public)
    var inspectionsPublisher: AnyPublisher<[Inspection], Never> {
        inspectionsSubject.eraseToAnyPublisher()
    }
    
    // STEP 3: Update Data và Send
    func createInspection(_ inspection: Inspection) async throws -> Inspection {
        let model = InspectionModel.fromEntity(inspection)
        let responseModel = try await service.createInspection(model)
        let newInspection = responseModel.toEntity()
        
        // Lấy giá trị hiện tại
        var currentInspections = inspectionsSubject.value
        
        // Thêm inspection mới vào đầu mảng
        currentInspections.insert(newInspection, at: 0)
        
        // 🔥 GỬI UPDATE ĐẾN TẤT CẢ SUBSCRIBERS
        inspectionsSubject.send(currentInspections)
        
        return newInspection
    }
}
```

## 📡 inspectionsSubject.send() Hoạt Động Như Thế Nào?

### Bước 1: Trước khi send()

```
┌─────────────────────────────────────────┐
│  inspectionsSubject                     │
│  Current Value: []                      │
│  (mảng rỗng - chưa có inspection)       │
└─────────────────────────────────────────┘
         │
         │ Có 2 Subscribers đang lắng nghe:
         ├──────────────────┐
         ↓                  ↓
┌──────────────────┐  ┌──────────────────┐
│ HomeViewModel    │  │ OtherViewModel   │
│ weeklyInspections│  │ someData         │
│ = []             │  │ = []             │
└──────────────────┘  └──────────────────┘
```

### Bước 2: Khi gọi send()

```swift
var currentInspections = inspectionsSubject.value  // Lấy: []
currentInspections.insert(newInspection, at: 0)    // Thêm: [inspection1]
inspectionsSubject.send(currentInspections)        // Gửi: [inspection1]
```

### Bước 3: Sau khi send()

```
┌─────────────────────────────────────────┐
│  inspectionsSubject                     │
│  Current Value: [inspection1]           │
│  ↓ BROADCAST TO ALL SUBSCRIBERS         │
└─────────────────────────────────────────┘
         │
         │ Tự động gửi đến tất cả subscribers
         ├──────────────────┐
         ↓                  ↓
┌──────────────────┐  ┌──────────────────┐
│ HomeViewModel    │  │ OtherViewModel   │
│ .sink { }        │  │ .sink { }        │
│ được gọi ✅      │  │ được gọi ✅      │
│ weeklyInspections│  │ someData         │
│ = [inspection1]  │  │ = [inspection1]  │
└──────────────────┘  └──────────────────┘
```

## 🔗 Publisher và Subscriber Pattern

### Trong PlanLMSHomeViewModel:

```swift
@MainActor
final class PlanLMSHomeViewModel: ObservableObject {
    @Published var weeklyInspections: [WeekSection] = []
    
    private let repository: InspectionRepositoryType
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: InspectionRepositoryType) {
        self.repository = repository
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // SUBSCRIBE (Đăng ký lắng nghe)
        repository.inspectionsPublisher  // ← Publisher từ Repository
            .receive(on: DispatchQueue.main)  // ← Nhận trên main thread
            .sink { [weak self] inspections in  // ← Closure được gọi khi có update
                guard let self = self else { return }
                
                // Khi inspectionsSubject.send() được gọi
                // → closure này TỰ ĐỘNG được trigger
                let sections = self.groupInspectionsByWeekUseCase.execute(inspections)
                self.weeklyInspections = sections  // ← Update UI
            }
            .store(in: &cancellables)  // ← Lưu để không bị deallocate
    }
}
```

### Flow Diagram:

```
┌────────────────────────────────────────────────────────────┐
│                    InspectionRepository                     │
│                                                             │
│  inspectionsSubject.send([inspection1, inspection2])       │
│                          │                                  │
└──────────────────────────┼──────────────────────────────────┘
                           │
                           │ Broadcast
                           │
        ┌──────────────────┼──────────────────┐
        ↓                  │                  ↓
┌───────────────┐   ┌──────────────┐   ┌────────────────┐
│ HomeViewModel │   │ ViewModel 2  │   │ ViewModel 3    │
│               │   │              │   │                │
│ .sink {       │   │ .sink {      │   │ .sink {        │
│   inspections │   │   inspections│   │   inspections  │
│   // ✅ Nhận  │   │   // ✅ Nhận  │   │   // ✅ Nhận    │
│ }             │   │ }            │   │ }              │
└───────────────┘   └──────────────┘   └────────────────┘
```

## 💡 Tại Sao Dùng Pattern Này?

### ❌ Cách Cũ (Không dùng Publisher):

```swift
// ViewModel 1
class HomeViewModel {
    var inspections: [Inspection] = []
    
    func refresh() {
        Task {
            inspections = try await repository.getInspections()
        }
    }
}

// ViewModel 2
class OtherViewModel {
    var inspections: [Inspection] = []
    
    func refresh() {
        Task {
            inspections = try await repository.getInspections()
        }
    }
}

// ❌ Vấn đề:
// 1. Mỗi ViewModel phải tự fetch data
// 2. Không đồng bộ giữa các ViewModels
// 3. Phải gọi refresh() manually
// 4. Nhiều API calls không cần thiết
```

### ✅ Cách Mới (Dùng Publisher):

```swift
// Repository
class InspectionRepository {
    private let subject = CurrentValueSubject<[Inspection], Never>([])
    var publisher: AnyPublisher<[Inspection], Never> {
        subject.eraseToAnyPublisher()
    }
    
    func createInspection() {
        // ...
        subject.send(newInspections)  // ← Gửi 1 lần
    }
}

// ViewModel 1
class HomeViewModel {
    init() {
        repository.publisher
            .sink { self.inspections = $0 }  // ← Tự động nhận
    }
}

// ViewModel 2
class OtherViewModel {
    init() {
        repository.publisher
            .sink { self.inspections = $0 }  // ← Tự động nhận
    }
}

// ✅ Lợi ích:
// 1. Gửi 1 lần → Tất cả nhận được
// 2. Tự động đồng bộ
// 3. Không cần gọi refresh()
// 4. Single source of truth
```

## 🎓 Các Khái Niệm Quan Trọng

### 1. Publisher

```swift
protocol Publisher {
    associatedtype Output      // Kiểu dữ liệu output
    associatedtype Failure     // Kiểu error
    
    func subscribe<S: Subscriber>(_ subscriber: S)
}
```

**Ví dụ:**
```swift
let publisher: AnyPublisher<[Inspection], Never>
                           │              │
                           │              └─ Failure = Never (không error)
                           └─ Output = [Inspection]
```

### 2. Subscriber

```swift
protocol Subscriber {
    associatedtype Input       // Phải match Publisher.Output
    associatedtype Failure     // Phải match Publisher.Failure
    
    func receive(_ input: Input)
}
```

**Ví dụ với .sink:**
```swift
publisher
    .sink { inspections in  // ← inspections là Input
        print(inspections)
    }
```

### 3. Cancellable

```swift
private var cancellables = Set<AnyCancellable>()

publisher
    .sink { ... }
    .store(in: &cancellables)  // ← Quan trọng!
```

**Tại sao cần .store()?**
- Subscription trả về `AnyCancellable`
- Nếu không lưu → bị deallocate ngay
- Subscription sẽ bị cancel → không nhận data

```swift
// ❌ SAI
publisher.sink { print($0) }  // ← Deallocate ngay → không nhận data

// ✅ ĐÚNG
publisher
    .sink { print($0) }
    .store(in: &cancellables)  // ← Lưu lại để giữ subscription
```

### 4. AnyPublisher

```swift
var inspectionsPublisher: AnyPublisher<[Inspection], Never> {
    inspectionsSubject.eraseToAnyPublisher()
}
```

**Tại sao dùng AnyPublisher?**
- **Type erasure**: Ẩn implementation details
- **Encapsulation**: External code chỉ biết là Publisher, không biết là Subject
- **Safety**: Ngăn external code gọi `.send()` trực tiếp

```swift
// ❌ Không dùng AnyPublisher
var inspectionsPublisher: CurrentValueSubject<[Inspection], Never> {
    inspectionsSubject
}
// Vấn đề: External code có thể gọi .send() → nguy hiểm!

// ✅ Dùng AnyPublisher
var inspectionsPublisher: AnyPublisher<[Inspection], Never> {
    inspectionsSubject.eraseToAnyPublisher()
}
// External code chỉ có thể subscribe, không thể send
```

## 🔄 Life Cycle Của Subscription

```
┌─────────────────────────────────────────────────────────┐
│ 1. SETUP SUBSCRIPTION                                    │
│    repository.publisher.sink { ... }                    │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 2. RECEIVE INITIAL VALUE                                 │
│    CurrentValueSubject → Send current value immediately  │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 3. WAIT FOR UPDATES                                      │
│    Subscription is active, waiting for send()           │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 4. RECEIVE NEW VALUE                                     │
│    inspectionsSubject.send([...]) → trigger .sink       │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 5. REPEAT STEP 3-4                                       │
│    Continue until cancellable is released                │
└────────────────────┬────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────────────┐
│ 6. CLEANUP                                               │
│    ViewModel deinit → cancellables.removeAll()          │
│    Subscription cancelled                                │
└─────────────────────────────────────────────────────────┘
```

## 🧪 Ví Dụ Đơn Giản

### Counter Example:

```swift
import Combine

class CounterRepository {
    // Subject lưu giá trị counter
    private let counterSubject = CurrentValueSubject<Int, Never>(0)
    
    // Expose Publisher
    var counterPublisher: AnyPublisher<Int, Never> {
        counterSubject.eraseToAnyPublisher()
    }
    
    // Tăng counter
    func increment() {
        let current = counterSubject.value  // Lấy: 0
        counterSubject.send(current + 1)    // Gửi: 1
    }
}

class CounterViewModel: ObservableObject {
    @Published var count: Int = 0
    private var cancellables = Set<AnyCancellable>()
    
    init(repository: CounterRepository) {
        // Subscribe
        repository.counterPublisher
            .sink { [weak self] newValue in
                self?.count = newValue  // ← UI tự động update
            }
            .store(in: &cancellables)
    }
}

// Usage:
let repo = CounterRepository()
let viewModel = CounterViewModel(repository: repo)

print(viewModel.count)  // Output: 0
repo.increment()        // → send(1)
// ViewModel's .sink được trigger
print(viewModel.count)  // Output: 1
```

## 📊 So Sánh Với Các Pattern Khác

| Pattern | Combine Publisher | NotificationCenter | Delegation | Closure Callback |
|---------|------------------|-------------------|------------|-----------------|
| **1-to-Many** | ✅ | ✅ | ❌ (1-to-1) | ❌ (1-to-1) |
| **Type-safe** | ✅ | ❌ | ✅ | ✅ |
| **Auto cleanup** | ✅ | ❌ | ⚠️ | ⚠️ |
| **Memory leak** | ❌ (with weak) | ⚠️ | ⚠️ | ⚠️ |
| **Composable** | ✅ | ❌ | ❌ | ❌ |
| **Thread-safe** | ✅ | ⚠️ | ⚠️ | ⚠️ |

## 🎯 Best Practices

### ✅ DO:

```swift
// 1. Dùng CurrentValueSubject cho state
private let stateSubject = CurrentValueSubject<State, Never>(.initial)

// 2. Expose AnyPublisher
var statePublisher: AnyPublisher<State, Never> {
    stateSubject.eraseToAnyPublisher()
}

// 3. Dùng [weak self] trong sink
repository.publisher
    .sink { [weak self] value in
        self?.handleUpdate(value)
    }
    .store(in: &cancellables)

// 4. Store cancellables
private var cancellables = Set<AnyCancellable>()
```

### ❌ DON'T:

```swift
// 1. ĐỪNG expose Subject trực tiếp
var statePublisher: CurrentValueSubject<State, Never> {
    stateSubject  // ← Nguy hiểm!
}

// 2. ĐỪNG quên weak self
repository.publisher
    .sink { value in
        self.data = value  // ← Memory leak!
    }

// 3. ĐỪNG quên store
repository.publisher
    .sink { print($0) }  // ← Không nhận data!
```

## 📚 Tài Liệu Tham Khảo

- [Apple Combine Documentation](https://developer.apple.com/documentation/combine)
- [Using Combine](https://heckj.github.io/swiftui-notes/)
- CurrentValueSubject vs PassthroughSubject
- Publisher và Subscriber Protocol

---

**Tóm tắt ngắn gọn:**

`inspectionsSubject.send(currentInspections)` = **Phát sóng** dữ liệu mới đến tất cả **người đăng ký** (subscribers) đang lắng nghe, giống như đài phát thanh phát tin tức mới đến tất cả radio đang bật!

🎯 **Key Point**: Một lần gửi → Tất cả nhận được → UI tự động update!
