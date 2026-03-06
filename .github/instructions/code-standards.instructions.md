---
applyTo: '**'
---
# Code Standards

## Naming Conventions

- **Types**: `UpperCamelCase` (structs, classes, protocols, enums)
- **Properties/Functions**: `lowerCamelCase`
- **Files**: Match primary type name
- **Protocols**: Descriptive names ending with `Type` or `Protocol`

## Import Order

```swift
// System frameworks
import Foundation
import SwiftUI

// Third-party frameworks (if any)
// import Alamofire

// Internal modules
// (none for main app target)
```

## File Organization

```swift
import SwiftUI

// MARK: - Properties
// MARK: - Initialization
// MARK: - Lifecycle
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Protocol Conformance
```

## SwiftUI View Structure

```swift
struct UserProfileView: View {
    // MARK: - Properties
    @StateObject private var viewModel: UserProfileViewModel
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Initialization
    init(viewModel: UserProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    var body: some View {
        contentView
            .navigationTitle("Profile")
            .task { await viewModel.loadData() }
    }
    
    // MARK: - Private Views
    private var contentView: some View {
        VStack(spacing: 16) {
            // View implementation
        }
    }
}

// MARK: - Preview
#Preview {
    UserProfileView(viewModel: UserProfileViewModel())
}
```

## ViewModel Structure

```swift
@MainActor
final class UserProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let fetchUserUseCase: FetchUserUseCase
    
    // MARK: - Initialization
    init(fetchUserUseCase: FetchUserUseCase) {
        self.fetchUserUseCase = fetchUserUseCase
    }
    
    // MARK: - Public Methods
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

## SwiftUI Best Practices

### State Management

- `@State` for local view state
- `@StateObject` for view-owned ObservableObjects
- `@ObservedObject` for injected ObservableObjects
- `@EnvironmentObject` for app-wide state
- `@Environment` for system values

### View Composition

```swift
// ✅ Good - Small, focused views
struct ProductCard: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProductImage(url: product.imageURL)
            ProductDetails(product: product)
            ProductActions(product: product)
        }
        .cardStyle()
    }
}

// ✅ Good - Reusable modifiers
extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.white)
            .cornerRadius(8)
            .shadow(radius: 2)
    }
}
```

### Async Operations

```swift
// ✅ Good - Use task modifier
.task {
    await viewModel.loadData()
}

// ✅ Good - Use async/await in ViewModels
@MainActor
func loadData() async {
    isLoading = true
    defer { isLoading = false }
    
    do {
        data = try await useCase.execute()
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

## Error Handling

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

## File Headers

```swift
//
//  FileName.swift
//  report_lms
//
//  Created by [Your Name] on [Date].
//  Copyright © 2026 report_lms. All rights reserved.
//
```

## Spacing and Formatting

- Use consistent indentation (4 spaces)
- Blank lines between major sections
- Group related code with `// MARK:` comments
- One blank line between functions
- No trailing whitespace

## Common Patterns

### Loading States

```swift
var body: some View {
    Group {
        if viewModel.isLoading {
            ProgressView()
        } else if let error = viewModel.errorMessage {
            ErrorView(message: error)
        } else {
            ContentView(data: viewModel.data)
        }
    }
}
```

### Optional Unwrapping

```swift
// ✅ Good - Optional binding
if let user = viewModel.user {
    UserDetailView(user: user)
}

// ✅ Good - Nil coalescing
Text(user?.name ?? "Unknown")

// ❌ Bad - Force unwrapping
Text(user!.name)
```

## MCP Integration

- Use MCP servers for enhanced AI context when available
- MCP configuration in `.cursor/mcp.json` or `.windsurf/mcp_config.json`
- Leverage MCP for semantic code understanding and analysis
