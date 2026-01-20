````prompt
---
description: "Generate basic Clean Architecture + SwiftUI module structure"
mode: "agent"
---

# iOS Basic Module Generator

Generate basic Clean Architecture + SwiftUI module with barebone structure following production patterns.

## Instructions

Reference our iOS development guidelines:

-   **Primary**: [iOS Guidelines](../instructions/ios-general-instructions.instructions.md)
-   **Fallback**: [AI Agent Context](../../AGENTS.md) (if primary unavailable)

Generate complete module structure with:

-   SwiftUI View with declarative UI
-   ViewModel implementing ObservableObject with @MainActor
-   Proper protocol definitions
-   LMS custom components or native SwiftUI
-   async/await patterns

## Template Variables

-   `${input:moduleName}`: Module name (e.g., "UserProfile")
-   `${input:featureName}`: Feature name (e.g., "report_lms")

## Output Files

1. **[ModuleName]View.swift** - SwiftUI view layer
2. **[ModuleName]ViewModel.swift** - Business logic with UseCase dependencies
3. **[ModuleName]Builder.swift** - Dependency injection setup (optional)

Each file follows production patterns with:

-   Required imports (SwiftUI, Combine)
-   Config enum for constants
-   Proper protocol structure
-   async/await patterns
-   TODO comments for implementation

## Generated Structure

### View Structure

```swift
import SwiftUI

struct [ModuleName]View: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel: [ModuleName]ViewModel
    @Environment(\.dismiss) private var dismiss
    
    enum Config {
        // TODO: Add configuration constants
        // static let spacing: CGFloat = 16
        // static let padding: CGFloat = 20
        // static let cornerRadius: CGFloat = 8
    }
    
    // MARK: - Initialization
    
    init(viewModel: [ModuleName]ViewModel = Container.shared.resolve([ModuleName]ViewModel.self)!) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Title")
                .toolbar { toolbarContent }
                .task { await viewModel.loadData() }
        }
    }
    
    // MARK: - Private Views
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: Config.spacing) {
                if viewModel.isLoading {
                    ProgressView()
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task { await viewModel.loadData() }
                    }
                } else {
                    // TODO: Add content views
                    // dataListView
                    // actionButtonsView
                }
            }
            .padding(Config.padding)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // TODO: Add toolbar items
        // ToolbarItem(placement: .navigationBarTrailing) {
        //     Button("Save") {
        //         Task { await viewModel.saveData() }
        //     }
        // }
    }
}

// MARK: - Preview

#Preview {
    [ModuleName]View(viewModel: [ModuleName]ViewModel.preview)
}
```

### ViewModel Structure

```swift
import SwiftUI
import Combine

@MainActor
final class [ModuleName]ViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    // TODO: Add @Published properties for UI state
    // @Published var items: [Item] = []
    // @Published var selectedItem: Item?
    
    // MARK: - Private Properties
    
    private let fetchDataUseCase: FetchDataUseCase
    // TODO: Add additional use case dependencies
    
    // MARK: - Initialization
    
    init(
        fetchDataUseCase: FetchDataUseCase
        // TODO: Add additional use case parameters
    ) {
        self.fetchDataUseCase = fetchDataUseCase
        // TODO: Initialize dependencies
    }
    
    // MARK: - Public Methods
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            // TODO: Implement data loading
            // let result = try await fetchDataUseCase.execute()
            // items = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // TODO: Add additional methods
    // func selectItem(_ item: Item) {
    //     selectedItem = item
    // }
    //
    // func deleteItem(at offsets: IndexSet) async {
    //     // Implementation
    // }
}

// MARK: - Preview Support

extension [ModuleName]ViewModel {
    static var preview: [ModuleName]ViewModel {
        [ModuleName]ViewModel(
            fetchDataUseCase: MockFetchDataUseCase()
        )
    }
    
    static var previewLoading: [ModuleName]ViewModel {
        let vm = preview
        vm.isLoading = true
        return vm
    }
    
    static var previewError: [ModuleName]ViewModel {
        let vm = preview
        vm.errorMessage = "Failed to load data"
        return vm
    }
}
```

### Builder Structure (Optional)

```swift
import Foundation

final class [ModuleName]Builder {
    
    // MARK: - Properties
    
    private let container: Container
    
    // MARK: - Initialization
    
    init(container: Container = .shared) {
        self.container = container
    }
    
    // MARK: - Build
    
    func build() -> [ModuleName]View {
        let viewModel = [ModuleName]ViewModel(
            fetchDataUseCase: container.resolve(FetchDataUseCase.self)!
            // TODO: Resolve additional use case dependencies from container
        )
        
        return [ModuleName]View(viewModel: viewModel)
    }
}
```

## Alternative Simplified ViewModel (No DI Container)

```swift
import SwiftUI

@MainActor
final class [ModuleName]ViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    // TODO: Add @Published properties
    
    // MARK: - Private Properties
    
    private let fetchDataUseCase: FetchDataUseCase
    
    // MARK: - Initialization
    
    init(
        fetchDataUseCase: FetchDataUseCase = FetchDataUseCase(
            repository: Container.shared.resolve(DataRepositoryType.self)!
        )
    ) {
        self.fetchDataUseCase = fetchDataUseCase
    }
    
    // MARK: - Public Methods
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            // TODO: Implementation
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

Keep all implementations minimal with clear TODO guidance.

````