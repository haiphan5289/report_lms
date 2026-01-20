````prompt
---
description: "Scaffold basic iOS files following Clean Architecture + SwiftUI patterns"
mode: "agent"
---

# iOS Basic File Scaffolding

Create basic barebone iOS files following Clean Architecture + SwiftUI and coding conventions.

## Instructions

Reference our iOS development guidelines:

-   **Primary**: [iOS Guidelines](../instructions/ios-general-instructions.instructions.md)
-   **Fallback**: [AI Agent Context](../../AGENTS.md) (if primary unavailable)

Generate basic scaffold files with:

-   Proper MARK sections and imports
-   Clean Architecture protocol structure
-   LMS custom components or native SwiftUI
-   async/await patterns
-   TODO comments for implementation

## Required Imports

```swift
import SwiftUI
import Combine // if needed for advanced state management
```

## SwiftUI View Template

```swift
import SwiftUI

struct [Name]View: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel: [Name]ViewModel
    @Environment(\.dismiss) private var dismiss
    
    enum Config {
        // TODO: Add configuration constants like sizes, spacing, padding
        // static let spacing: CGFloat = 16
        // static let padding: CGFloat = 20
        // static let cornerRadius: CGFloat = 8
    }
    
    // MARK: - Initialization
    
    init(viewModel: [Name]ViewModel = [Name]ViewModel()) {
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
                        Task { await viewModel.retry() }
                    }
                } else {
                    // TODO: Add content views
                }
            }
            .padding(Config.padding)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // TODO: Add toolbar items
        // ToolbarItem(placement: .navigationBarTrailing) {
        //     Button("Action") {
        //         Task { await viewModel.performAction() }
        //     }
        // }
    }
}

// MARK: - Preview

#Preview {
    [Name]View(viewModel: [Name]ViewModel.preview)
}
```

## ViewModel Template

```swift
import SwiftUI

@MainActor
final class [Name]ViewModel: ObservableObject {
    
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
            // TODO: Implement data loading
            // let result = try await fetchDataUseCase.execute()
            // items = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func retry() async {
        await loadData()
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

extension [Name]ViewModel {
    static var preview: [Name]ViewModel {
        [Name]ViewModel()
    }
}
```

## File Types to Generate

Based on the file type requested, generate the appropriate files:

### View (${input:fileName})

-   Create SwiftUI View with proper MARK organization
-   Include proper imports and lifecycle methods
-   Follow naming conventions with "View" suffix
-   Use native SwiftUI or LMS custom components

### ViewModel (${input:fileName})

-   Create ViewModel with @MainActor and ObservableObject
-   Include @Published properties for state
-   Use proper async/await patterns
-   Include proper initialization and dependency injection

### UseCase (${input:fileName})

-   Create UseCase following Clean Architecture
-   Include proper Input/Output if needed
-   Implement repository pattern integration
-   Include proper error handling with async/await

### Repository (${input:fileName})

-   Create Repository protocol and implementation
-   Include proper service layer integration
-   Follow dependency injection patterns
-   Use async/await (no completion handlers)

### Service (${input:fileName})

-   Create Service protocol and implementation
-   Include proper URLSession integration
-   Use async/await for network calls
-   Include proper error handling and mapping

### Entity (${input:fileName})

-   Create entity with proper property definitions
-   Include Identifiable and Equatable conformance
-   Follow proper naming conventions
-   Include preview support

### Model (${input:fileName})

-   Create model with proper property definitions
-   Include Codable conformance for API responses
-   Add toEntity() mapping method
-   Include proper documentation

### Row/Item Component (${input:fileName})

-   Create SwiftUI component for List or Grid
-   Include ViewModel for configuration
-   Follow reusable patterns
-   Use native SwiftUI or LMS custom components

## UseCase Template

```swift
import Foundation

final class [Name]UseCase {
    
    // MARK: - Properties
    
    private let repository: [Name]RepositoryType
    
    // MARK: - Initialization
    
    init(repository: [Name]RepositoryType) {
        self.repository = repository
    }
    
    // MARK: - Execute
    
    func execute() async throws -> [ResultEntity] {
        try await repository.fetchData()
    }
}
```

## Entity Template

```swift
import Foundation

struct [Name]Entity: Identifiable, Equatable {
    
    // MARK: - Properties
    
    let id: String
    // TODO: Add entity properties
    // let name: String
    // let description: String?
    // let createdAt: Date
    
    // MARK: - Computed Properties
    
    // TODO: Add computed properties
    // var displayName: String {
    //     name.isEmpty ? "Unnamed" : name
    // }
}

// MARK: - Preview Support

extension [Name]Entity {
    static var preview: [Name]Entity {
        [Name]Entity(
            id: "preview-1"
            // TODO: Add preview values
        )
    }
}
```

## Model Template

```swift
import Foundation

struct [Name]Model: Codable {
    
    // MARK: - Properties
    
    let id: String
    // TODO: Add model properties matching API response
    // let name: String
    // let description: String?
    // let createdAt: String
    
    // MARK: - CodingKeys
    
    enum CodingKeys: String, CodingKey {
        case id
        // TODO: Map API keys if different from property names
        // case name = "display_name"
        // case description
        // case createdAt = "created_at"
    }
    
    // MARK: - Mapping
    
    func toEntity() -> [Name]Entity {
        [Name]Entity(
            id: id
            // TODO: Map model properties to entity
            // name: name,
            // description: description,
            // createdAt: ISO8601DateFormatter().date(from: createdAt) ?? Date()
        )
    }
}
```

## Template Variables

-   `${input:fileName}`: The base name (e.g., "UserProfile", "CourseDetail")
-   `${input:module}`: The module name (e.g., "report_lms")
-   `${input:fileType}`: The file type (View, ViewModel, UseCase, etc.)

## Output

Generate basic scaffolding with:

1. Required imports (SwiftUI, Combine if needed)
2. Proper MARK sections
3. Clean Architecture protocol structure
4. async/await patterns (no completion handlers)
5. Config enum for constants
6. @Published properties for state management
7. TODO comments for implementation
8. Preview support for SwiftUI components

Keep implementations minimal with TODO guidance for developers.

````