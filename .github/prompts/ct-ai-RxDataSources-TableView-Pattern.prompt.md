# SwiftUI List Multiple Sections Pattern

## Overview
Standardized pattern for implementing List with multiple sections using SwiftUI native features with Clean Architecture.

## Required Imports
```swift
import SwiftUI
```

## 1. Section Type Enum Definition
```swift
enum ListSection: Identifiable {
    case section1(Model1)
    case section2([Model2])
    case section3(Model3)
    
    var id: String {
        switch self {
        case .section1: return "section1"
        case .section2: return "section2"
        case .section3: return "section3"
        }
    }
}
```

## 2. ViewModel with Section Management
```swift
@MainActor
final class ContentViewModel: ObservableObject {
    @Published var sections: [ListSection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let fetchDataUseCase: FetchDataUseCase
    
    init(fetchDataUseCase: FetchDataUseCase) {
        self.fetchDataUseCase = fetchDataUseCase
    }
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let data = try await fetchDataUseCase.execute()
            setupSections(with: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func setupSections(with data: DataModel) {
        var newSections: [ListSection] = []
        
        // Section 1
        if let model1 = data.model1 {
            newSections.append(.section1(model1))
        }
        
        // Section 2
        if !data.model2Array.isEmpty {
            newSections.append(.section2(data.model2Array))
        }
        
        // Section 3 (Multiple items)
        for item in data.model3Array {
            newSections.append(.section3(item))
        }
        
        sections = newSections
    }
}
```

## 3. SwiftUI View with List
```swift
struct ContentListView: View {
    @StateObject private var viewModel: ContentViewModel
    
    init(viewModel: ContentViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task { await viewModel.loadData() }
                    }
                } else {
                    contentList
                }
            }
            .navigationTitle("Content")
            .task {
                await viewModel.loadData()
            }
        }
    }
    
    private var contentList: some View {
        List(viewModel.sections) { section in
            sectionView(for: section)
        }
    }
    
    @ViewBuilder
    private func sectionView(for section: ListSection) -> some View {
        switch section {
        case .section1(let model):
            Section1Row(model: model)
                .onTapGesture {
                    handleSection1Tap(model: model)
                }
            
        case .section2(let models):
            Section2Row(count: models.count)
                .onTapGesture {
                    handleSection2Tap(models: models)
                }
            
        case .section3(let model):
            Section3Row(model: model)
                .onTapGesture {
                    handleSection3Tap(model: model)
                }
        }
    }
    
    // MARK: - Navigation Handlers
    private func handleSection1Tap(model: Model1) {
        // Handle section1 tap
    }
    
    private func handleSection2Tap(models: [Model2]) {
        // Handle section2 tap
    }
    
    private func handleSection3Tap(model: Model3) {
        // Handle section3 tap
    }
}
```

## 4. Row Components
```swift
struct Section1Row: View {
    let model: Model1
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(.headline)
                Text(model.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct Section2Row: View {
    let count: Int
    
    var body: some View {
        HStack {
            Text("\(count) items")
                .font(.body)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct Section3Row: View {
    let model: Model3
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)
                Text(model.info)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}
```

## 5. Alternative: Using ForEach with Sections
```swift
struct ContentListView: View {
    @StateObject private var viewModel: ContentViewModel
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.sections) { section in
                    sectionView(for: section)
                }
            }
            .navigationTitle("Content")
            .task {
                await viewModel.loadData()
            }
        }
    }
}
```

## 6. Grouped Sections Pattern
```swift
struct GroupedContentListView: View {
    @StateObject private var viewModel: ContentViewModel
    
    var body: some View {
        List {
            if let section1 = viewModel.section1Data {
                Section("Section 1") {
                    Section1Row(model: section1)
                        .onTapGesture {
                            handleSection1Tap(model: section1)
                        }
                }
            }
            
            if !viewModel.section2Data.isEmpty {
                Section("Section 2") {
                    ForEach(viewModel.section2Data) { item in
                        Section2ItemRow(item: item)
                            .onTapGesture {
                                handleSection2ItemTap(item: item)
                            }
                    }
                }
            }
            
            if !viewModel.section3Data.isEmpty {
                Section("Section 3") {
                    ForEach(viewModel.section3Data) { item in
                        Section3ItemRow(item: item)
                            .onTapGesture {
                                handleSection3ItemTap(item: item)
                            }
                    }
                }
            }
        }
    }
}
```

## Usage Template

### Step 1: Define Section Type
```swift
enum YourListSection: Identifiable {
    case yourSection1(YourModel1)
    case yourSection2([YourModel2])
    
    var id: String {
        switch self {
        case .yourSection1: return "section1"
        case .yourSection2: return "section2"
        }
    }
}
```

### Step 2: Create ViewModel
```swift
@MainActor
final class YourViewModel: ObservableObject {
    @Published var sections: [YourListSection] = []
    @Published var isLoading = false
    
    func loadData() async {
        // Load and setup sections
    }
}
```

### Step 3: Build View
```swift
struct YourListView: View {
    @StateObject private var viewModel: YourViewModel
    
    var body: some View {
        List(viewModel.sections) { section in
            // Render section
        }
        .task {
            await viewModel.loadData()
        }
    }
}
```

### Step 4: Add Preview
```swift
#Preview {
    YourListView(viewModel: YourViewModel(useCase: MockUseCase()))
}
```

## Key Benefits
- ✅ Type-safe section management
- ✅ Declarative SwiftUI syntax
- ✅ Automatic UI updates with @Published
- ✅ Clean separation of concerns
- ✅ Easy to extend with new sections
- ✅ Native SwiftUI performance
- ✅ Follows Clean Architecture + SwiftUI pattern

## Notes
- Use `@MainActor` on ViewModels for UI updates
- Use `@Published` properties for reactive updates
- Use `.task` modifier for async loading
- Keep row components in separate files for reusability
- Use `Identifiable` protocol for list items
- Handle empty states gracefully
