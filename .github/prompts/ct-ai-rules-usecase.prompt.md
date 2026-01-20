# Use Case Generation Prompt with Serena Integration

Goal: Generate a complete use case implementation following MVVM + Clean Architecture using Serena's semantic understanding.

## Enhanced Workflow with Serena

### 1. Analysis Phase

```bash
# Analyze similar existing use cases
make serena-analyze FEATURE=CTAuthentication

# Find related patterns in codebase
./bin/serena-ios-dev.sh analyze Authentication
```

### 2. Automated Generation

```bash
# Generate complete 6-layer implementation
make serena-usecase NAME=CreateUser ENDPOINT=/api/users INPUT=CreateUserRequest OUTPUT=User

# Serena will automatically create:
# - NetworkHelper endpoint definition
# - Target conforming to Requestable
# - Service method implementation
# - Repository protocol and implementation
# - UseCase with CTActionUseCaseType
# - ViewModel execution method
# - Comprehensive unit tests
```

### 3. Integration & Validation

```bash
# Check architecture compliance
make serena-check-arch

# Generate test structure if needed
make serena-generate-tests CLASS=CreateUserViewModel
```

## Requirements

### Core Implementation

- **3-Layer Architecture**: Presentation → Domain ← Data
- **Input/Output Models**: Type-safe domain entities in Domain layer
- **Repository Abstraction**: Protocol-based DI
- **Async/Await**: Modern Swift concurrency with proper error handling
- **SwiftUI**: Native SwiftUI components throughout UI layer
- **Declarative Layout**: SwiftUI declarative syntax

### Testing & Quality

- **Unit Tests**: XCTest with Given-When-Then pattern
- **Mock Generation**: Protocol-based mock creation for dependencies
- **Architecture Compliance**: Clean Architecture pattern validation
- **Code Coverage**: Minimum 80% target with automated checks

### Architecture Features

- **Protocol-First Design**: All repositories use protocol abstractions
- **Dependency Injection**: Constructor injection for all dependencies
- **SwiftUI Patterns**: @StateObject, @Published, @MainActor
- **Immutability**: Prefer immutable models in Domain layer
- **Testability**: Design for easy unit testing

## Architecture Benefits

### Productivity Improvements

- **Reduced Boilerplate**: Minimal boilerplate with SwiftUI
- **Pattern Consistency**: Adherence to Clean Architecture principles
- **Type Safety**: Compile-time error detection
- **Rapid Development**: SwiftUI's declarative syntax and live previews

### Quality Enhancements

- **Architecture Compliance**: Clean Architecture pattern enforcement
- **Code Standards**: Consistent with project guidelines
- **Testing Coverage**: Comprehensive unit test structure
- **SwiftUI Previews**: Visual component development and testing

## Deliverables

### 1. Complete Implementation

- **Service Layer**: API implementations with async/await error handling (Data/Services/)
- **Repository Layer**: Protocol-based abstraction and implementation
- **Use Case Layer**: Business logic with async/await (Domain/UseCases/)
- **ViewModel Layer**: UI presentation logic with @MainActor and @Published properties
- **View Layer**: SwiftUI declarative views
- **Test Layer**: Comprehensive XCTest unit tests with mocks

### 2. Quality Assurance

- **Architecture Validation**: Clean Architecture pattern compliance
- **Code Analysis**: Swift best practices and conventions
- **Import Organization**: Consistent import ordering
- **Preview Providers**: SwiftUI preview configurations

### 3. Integration Ready

- **Dependency Injection**: Constructor-based DI setup
- **Error Handling**: User-friendly error messages with proper async error handling
- **Loading States**: Proper @Published state management
- **Accessibility**: SwiftUI accessibility modifiers

## Usage Example

```swift
// Domain Layer - Use Case
final class UpdateUserProfileUseCase {
    private let repository: UserRepositoryType
    
    init(repository: UserRepositoryType) {
        self.repository = repository
    }
    
    func execute(request: UpdateProfileRequest) async throws -> UserProfile {
        try await repository.updateProfile(request: request)
    }
}

// Presentation Layer - ViewModel
@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let updateUseCase: UpdateUserProfileUseCase
    
    init(updateUseCase: UpdateUserProfileUseCase) {
        self.updateUseCase = updateUseCase
    }
    
    func updateProfile(request: UpdateProfileRequest) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            profile = try await updateUseCase.execute(request: request)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

## References

- **Architecture**: .github/instructions/architecture.md
- **Code Standards**: .github/instructions/code-standards.md
- **Code Style**: .github/instructions/code-style.md
- **Testing**: .github/instructions/testing.md
- **Project Overview**: .github/copilot-instructions.md

---

*This workflow delivers production-ready use cases following Clean Architecture + SwiftUI patterns with modern Swift concurrency.*
