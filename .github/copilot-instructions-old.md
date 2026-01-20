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


## Project Structure (Target Architecture)

```
report_lms/
├── report_lms/
│   ├── report_lmsApp.swift           # App entry point
│   ├── Resources/                    # Assets and resources
│   │   └── Images.xcassets/
│   └── Sources/
│       ├── Common/                   # Shared utilities
│       │   ├── Components/           # Reusable SwiftUI components
│       │   ├── Extensions/           # Swift extensions
│       │   ├── Modifiers/            # SwiftUI view modifiers
│       │   └── Types/                # Common types and enums
│       ├── Data/                     # Data Layer
│       │   ├── Models/               # API response models
│       │   ├── Repositories/         # Repository implementations
│       │   └── Services/             # Network/API services
│       ├── Domain/                   # Domain Layer
│       │   ├── Entities/             # Business entities
│       │   ├── Repositories/         # Repository protocols
│       │   └── UseCases/             # Business logic use cases
│       ├── DI/                       # Dependency Injection
│       │   └── Container+*.swift     # DI container extensions
│       ├── Helper/                   # Helper utilities
│       └── Presentation/             # Presentation Layer
│           ├── Components/           # Shared UI components
│           └── Modules/              # Feature modules
│               └── [FeatureName]/
│                   ├── Views/        # SwiftUI views
│                   ├── ViewModels/   # ObservableObject ViewModels
│                   └── Components/   # Feature-specific components
├── report_lms.xcodeproj/
└── .github/
    ├── prompts/                      # Advanced scaffolding templates
    └── instructions/                 # Detailed iOS conventions
```

## Architecture: Clean Architecture + SwiftUI

### Three-Layer Pattern

**1. Presentation Layer** (`Presentation/`)
- SwiftUI Views with declarative UI
- ViewModels (ObservableObject) managing state and business logic
- Feature-specific components and modifiers

**2. Domain Layer** (`Domain/`)
- Business entities (pure Swift models)
- Repository protocols (abstractions)
- Use Cases (business logic operations)
- Independent of UI and frameworks

**3. Data Layer** (`Data/`)
- Repository implementations
- API services and network clients
- Data models (Codable) for API responses
- Local storage implementations

### Dependency Flow
```
Presentation → Domain ← Data
```
- Presentation depends on Domain (uses entities, use cases)
- Data depends on Domain (implements repository protocols)
- Domain has NO dependencies (pure business logic)

### Code Style
- **Naming**: 
  - Types: `UpperCamelCase` (structs, classes, protocols, enums)
  - Properties/Functions: `lowerCamelCase`
  - Files: Match primary type name
  - Protocols: Descriptive names ending with `Type` or `Protocol`
- **Organization**: Use `// MARK:` comments to organize code sections
- **Spacing**: Consistent indentation, blank lines between major sections

### Dependency Injection Pattern
```swift
// Container extension for dependencies
extension Container {
    static func registerRepositories() {
        shared.register(UserRepositoryType.self) { _ in
            UserRepository(service: Container.shared.resolve(UserServiceType.self)!)
        }
    }
    
    static func registerUseCases() {
        shared.register(FetchUserUseCase.self) { _ in
            FetchUserUseCase(repository: Container.shared.resolve(UserRepositoryType.self)!)
        }
    }
}
```

### Clean Architecture Implementation

**Domain Layer - Entity:**
```swift
// Domain/Entities/User.swift
struct User: Identifiable, Equatable {
    let id: String
    let name: String
    let email: String
}
```

**Domain Layer - Repository Protocol:**
```swift
// Domain/Repositories/UserRepositoryType.swift
protocol UserRepositoryType {
    func fetchUser(id: String) async throws -> User
}
```

**Domain Layer - Use Case:**
```swift
// Domain/UseCases/FetchUserUseCase.swift
finDevelopment Principles

1. **Clean Architecture**: Follow three-layer separation (Presentation → Domain ← Data)
2. **Dependency Inversion**: Depend on abstractions (protocols), not concretions
3. **Single Responsibility**: Each class/struct has one clear purpose
4. **Testability**: Design for easy unit testing with dependency injection
5. **SwiftUI Native**: Use modern SwiftUI patterns (async/await, @MainActor)
6. **Immutability**: Prefer immutable models in Domain layer

## Common Development Tasks

### 1. Create New Feature Module

**Structure:**
```
Presentation/Modules/[FeatureName]/
├── Views/
│   └── [FeatureName]View.swift
├── ViewModels/
│   └── [FeatureName]ViewModel.swift
└── Components/
    └── [FeatureName]Components.swift
```

### 2. Create New Use Case

**Steps:**
1. Define Entity in `Domain/Entities/`
2. Define Repository protocol in `Domain/Repositories/`
3. Create Use Case in `Domain/UseCases/`
4. Implement Repository in `Data/Repositories/`
5. Create Service in `Data/Services/`
6. Register dependencies in `DI/Container+*.swift`

### 3. Add New API Endpoint

**Steps:**
1. Create Data Model in `Data/Models/` (Codable)
2. Add service method in `Data/Services/`
3. Update repository implementation
4. Add `toEntity()` method to convert Model → Entity

### 4. Create Reusable Component

**Location:** `Common/Components/` or `Presentation/Components/`
```swift
// Common/Components/LoadingView.swift
struct LoadingView: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
    }
}
```

### 5. Add Custom View Modifier

**Location:** `Common/Modifiers/`
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
        modifier(CardModifier())mentation
    }
}
```

**Data Layer - Repository:**
```swift
// Data/Repositories/UserRepository.swift
final class UserRepository: UserRepositoryType {
    private let service: UserServiceType
    
    init(service: UserServiceType) {
        self.service = service
    }
    
    func fetchUser(id: String) async throws -> User {
        let model = try await service.getUser(id: id)
        return model.toEntity()
    }
}
```

**Presentation Layer - ViewModel:**
```swift
// Presentation/Modules/UserProfile/ViewModels/UserProfileViewModel.swift
@MainActor
final class UserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let fetchUserUseCase: FetchUserUseCase
    
    init(fetchUserUseCase: FetchUserUseCase) {
        self.fetchUserUseCase = fetchUserUseCase
    }
    
    func loadUser(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            user = try await fetchUserUseCase.execute(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```
Testing Strategy

### Unit Testing Structure
```swift
// report_lmsTests/Domain/UseCases/FetchUserUseCaseTests.swift
import XCTest
@testable import report_lms

final class FetchUserUseCaseTests: XCTestCase {
    var sut: FetchUserUseCase!
    var mockRepository: MockUserRepository!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockUserRepository()
        sut = FetchUserUseCase(repository: mockRepository)
    }
    
    func testExecute_Success() async throws {
        // Given
        let expectedUser = User(id: "1", name: "Test", email: "test@example.com")
        mockRepository.mockUser = expectedUser
        
        // When
        let result = try await sut.execute(userId: "1")
        
        // Then
        XCTAssertEqual(result, expectedUser)
    }
}

// Mock Repository
final class MockUserRepository: UserRepositoryType {
    var mockUser: User?
    var shouldThrowError = false
    
    func fetchUser(id: String) async throws -> User {
        if shouldThrowError { throw NSError(domain: "test", code: -1) }
        return mockUser!
    }
}
```

## Building and Running

- **Build**: Use Xcode (`Cmd+B`) or `xcodebuild`
- **Run**: Use Xcode (`Cmd+R`) or Simulator
- *File Organization Standards

### Import Order
```swift
// System frameworks
import Foundation
import SwiftUI

// Third-party frameworks (if any)
// import Alamofire

// Internal modules
// (none for main app target)
```

### MARK Comments Structure
```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Lifecycle
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Protocol Conformance
```

## Error Handling Pattern

```swift
// Common/Types/AppError.swift
enum AppError: LocalizedError {
    case networkError(Error)
    case invalidData
    case notFound
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid data received"
        case .notFound:
            return "Resource not found"
        case .unauthorized:
            return "Unauthorized access"
        }
    }
}
```

## Best Practices Summary

1. **Always use async/await** for asynchronous operations (no completion handlers)
2. **Use @MainActor** for ViewModels to ensure UI updates on main thread
3. **Protocol-first design** for all repositories and services
4. **Dependency injection** through constructor injection
5. **Keep Views dumb** - all logic in ViewModels or Use Cases
6. **Separate concerns** - Models (Data) vs Entities (Domain)
7. **Use PreviewProvider** for SwiftUI component development
8. **Error handling** - use Result type or throws for domain operations

## Quick Reference: CTEcommerce Pattern

The CTEcommerce module demonstrates:
- ✅ Clean Architecture with clear layer separation
- ✅ Dependency Injection using Container pattern
- ✅ SwiftUI with ObservableObject ViewModels
- ✅ Repository pattern for data access
- ✅ Use Cases for business logic
- ✅ Reusable components and modifiers
- ✅ Proper resource organization (Images.xcassets)

**Reference Structure:** Follow CTEcommerce folder organization as the blueprint for report_lms
                ProgressView()
            } else if let user = viewModel.user {
                ProfileHeader(user: user)
                ProfileDetails(user: user)
            }
        }
        .task { await viewModel.loadUser(userId: "123") }
    }
}
```

### File Headers
```swift
//
//  FileName.swift
//  report_lms
//
//  Created by [Your Name] on [Date].
//  Copyright © 2026 report_lms. All rights reserved.
//
```

## Building and Running

- **Build**: Use Xcode (`Cmd+B`) or `xcodebuild`
- **Run**: Use Xcode (`Cmd+R`) or Simulator
- **Platform**: iOS (check project settings for minimum version)

## Key Principles

1. **Keep it Simple**: This is a SwiftUI project - use native SwiftUI patterns, not UIKit
2. **Modern Swift**: Use latest Swift features (async/await, @MainActor, etc.)
3. **SwiftUI Lifecycle**: Use SwiftUI's declarative lifecycle methods
4. **No External Dependencies**: Start with native SwiftUI/Swift before adding dependencies

## Common Tasks

### Create New View
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

### Create ViewModel
```swift
import Foundation

@MainActor
class NewFeatureViewModel: ObservableObject {
    @Published var data: [Item] = []
    @Published var isLoading = false
    
    func loadData() async {
        // Implementation
    }
}
```

## Advanced Scaffolding (Reference Only)

The `.github/prompts/` directory contains sophisticated scaffolding templates from the "Cho Tot iOS" project (MVVM+Clean Architecture with UIKit, RxSwift, CTDesignSystem). These are advanced enterprise patterns:

- **Not applicable to this SwiftUI project** by default
- Useful for understanding enterprise iOS patterns
