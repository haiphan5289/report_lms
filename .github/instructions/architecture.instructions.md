# Clean Architecture + SwiftUI

## Three-Layer Pattern

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

## Dependency Flow

```
Presentation → Domain ← Data
```

- Presentation depends on Domain (uses entities, use cases)
- Data depends on Domain (implements repository protocols)
- Domain has NO dependencies (pure business logic)

## Development Principles

1. **Clean Architecture**: Follow three-layer separation (Presentation → Domain ← Data)
2. **Dependency Inversion**: Depend on abstractions (protocols), not concretions
3. **Single Responsibility**: Each class/struct has one clear purpose
4. **Testability**: Design for easy unit testing with dependency injection
5. **SwiftUI Native**: Use modern SwiftUI patterns (async/await, @MainActor)
6. **Immutability**: Prefer immutable models in Domain layer

## Layer Implementation Examples

### Domain Layer - Entity

```swift
// Domain/Entities/User.swift
struct User: Identifiable, Equatable {
    let id: String
    let name: String
    let email: String
}
```

### Domain Layer - Repository Protocol

```swift
// Domain/Repositories/UserRepositoryType.swift
protocol UserRepositoryType {
    func fetchUser(id: String) async throws -> User
}
```

### Domain Layer - Use Case

```swift
// Domain/UseCases/FetchUserUseCase.swift
final class FetchUserUseCase {
    private let repository: UserRepositoryType
    
    init(repository: UserRepositoryType) {
        self.repository = repository
    }
    
    func execute(userId: String) async throws -> User {
        try await repository.fetchUser(id: userId)
    }
}
```

### Data Layer - Model

```swift
// Data/Models/UserModel.swift
struct UserModel: Codable {
    let id: String
    let name: String
    let email: String
    
    func toEntity() -> User {
        User(id: id, name: name, email: email)
    }
}
```

### Data Layer - Service

```swift
// Data/Services/UserService.swift
protocol UserServiceType {
    func getUser(id: String) async throws -> UserModel
}

final class UserService: UserServiceType {
    func getUser(id: String) async throws -> UserModel {
        // API call implementation
    }
}
```

### Data Layer - Repository

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

### Presentation Layer - ViewModel

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

### Presentation Layer - View

```swift
// Presentation/Modules/UserProfile/Views/UserProfileView.swift
struct UserProfileView: View {
    @StateObject private var viewModel: UserProfileViewModel
    
    init(viewModel: UserProfileViewModel = Container.shared.resolve(UserProfileViewModel.self)!) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoading {
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

## Dependency Injection Pattern

```swift
// DI/Container+Dependencies.swift
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

## Best Practices

1. **Always use async/await** for asynchronous operations (no completion handlers)
2. **Use @MainActor** for ViewModels to ensure UI updates on main thread
3. **Protocol-first design** for all repositories and services
4. **Dependency injection** through constructor injection
5. **Keep Views dumb** - all logic in ViewModels or Use Cases
6. **Separate concerns** - Models (Data) vs Entities (Domain)
7. **Use PreviewProvider** for SwiftUI component development
8. **Error handling** - use Result type or throws for domain operations
