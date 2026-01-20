# report_lms - AI Agent Instructions

## Project Overview

SwiftUI-based iOS application for learning management system (LMS) reporting using **Clean Architecture + SwiftUI** pattern.

## Quick Links

- **Architecture**: See [instructions/architecture.md](instructions/architecture.md)
- **Code Standards**: See [instructions/code-standards.md](instructions/code-standards.md)
- **Code Style**: See [instructions/code-style.md](instructions/code-style.md)
- **Testing**: See [instructions/testing.md](instructions/testing.md)

## Project Structure

```
report_lms/
├── report_lms/
│   ├── report_lmsApp.swift
│   ├── Resources/
│   │   └── Images.xcassets/
│   └── Sources/
│       ├── Common/
│       │   ├── Components/
│       │   ├── Extensions/
│       │   ├── Modifiers/
│       │   └── Types/
│       ├── Data/
│       │   ├── Models/
│       │   ├── Repositories/
│       │   └── Services/
│       ├── Domain/
│       │   ├── Entities/
│       │   ├── Repositories/
│       │   └── UseCases/
│       ├── DI/
│       ├── Helper/
│       └── Presentation/
│           ├── Components/
│           └── Modules/
├── report_lms.xcodeproj/
└── .github/
    ├── prompts/
    └── instructions/
```

## Quick Start

### Create New Feature

1. **Define Domain Layer**:
   - Create Entity in `Domain/Entities/`
   - Create Repository protocol in `Domain/Repositories/`
   - Create Use Case in `Domain/UseCases/`

2. **Implement Data Layer**:
   - Create Model in `Data/Models/`
   - Create Service in `Data/Services/`
   - Implement Repository in `Data/Repositories/`

3. **Build Presentation Layer**:
   - Create ViewModel in `Presentation/Modules/[Feature]/ViewModels/`
   - Create View in `Presentation/Modules/[Feature]/Views/`

4. **Register Dependencies**:
   - Add to `DI/Container+*.swift`

## Common Development Tasks

### 1. Create New View

```swift
import SwiftUI

struct NewFeatureView: View {
    @StateObject private var viewModel = NewFeatureViewModel()
    
    var body: some View {
        // View implementation
    }
}

#Preview {
    NewFeatureView()
}
```

### 2. Create ViewModel

```swift
@MainActor
final class NewFeatureViewModel: ObservableObject {
    @Published var data: [Item] = []
    @Published var isLoading = false
    
    func loadData() async {
        // Implementation
    }
}
```

### 3. Create Use Case

```swift
final class FetchDataUseCase {
    private let repository: DataRepositoryType
    
    init(repository: DataRepositoryType) {
        self.repository = repository
    }
    
    func execute() async throws -> [DataEntity] {
        try await repository.fetchData()
    }
}
```

### 4. Create Reusable Component

```swift
// Common/Components/LoadingView.swift
struct LoadingView: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
    }
}
```

### 5. Add Custom Modifier

```swift
// Common/Modifiers/CardModifier.swift
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.white)
            .cornerRadius(8)
            .shadow(radius: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}
```

## Key Principles

1. **Clean Architecture**: Three-layer separation (Presentation → Domain ← Data)
2. **SwiftUI Native**: Use modern SwiftUI patterns (async/await, @MainActor)
3. **Protocol-First**: Depend on abstractions, not concretions
4. **Testability**: Design for easy unit testing with dependency injection
5. **Immutability**: Prefer immutable models in Domain layer

## MCP Integration

- Use MCP servers for enhanced AI context when available
- MCP configuration in `.cursor/mcp.json` or `.windsurf/mcp_config.json`
- Leverage MCP for semantic code understanding and analysis

## Building and Running

- **Build**: Use Xcode (`Cmd+B`) or `xcodebuild`
- **Run**: Use Xcode (`Cmd+R`) or Simulator
- **Test**: Use Xcode Test Navigator (`Cmd+U`)
- **Platform**: iOS (check project settings for minimum version)
