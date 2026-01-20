````prompt
---
mode: agent
description: Generate ViewModel UseCase execution methods following Clean Architecture + SwiftUI pattern for iOS application
---

# ViewModel UseCase Execution Guide

## Overview
This guide provides instructions for adding UseCase execution methods to ViewModels in the iOS application following the Clean Architecture + SwiftUI pattern.

## Task Definition
Define the task to achieve ViewModel UseCase execution integration, including specific requirements, constraints, and success criteria.

## Required Parameters

When generating a ViewModel UseCase execution method, you need to provide the following parameters:

- `{USECASE_NAME}`: The name of the UseCase (e.g., FetchUserProfile, UpdateSettings)
- `{INPUT_PARAM}`: The input parameter type for the UseCase (e.g., String, UserRequest)
- `{VIEWMODEL_CLASS}`: The ViewModel class name where the execution method will be added
- `{USECASE_PROPERTY}`: The use case property name in the ViewModel

## Add ViewModel UseCase Execution Method

Add the following UseCase execution method to {VIEWMODEL_CLASS} file:

```swift
// ⚠️ ADD THIS METHOD TO EXISTING {VIEWMODEL_CLASS} CLASS ⚠️
@MainActor
final class {VIEWMODEL_CLASS}: ObservableObject {
    @Published var data: ResponseModel?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let {USECASE_PROPERTY}: {USECASE_NAME}UseCase
    
    init({USECASE_PROPERTY}: {USECASE_NAME}UseCase) {
        self.{USECASE_PROPERTY} = {USECASE_PROPERTY}
    }
    
    func execute{USECASE_NAME}(input: {INPUT_PARAM}) async {
        // 🔒 MANDATORY: Handle loading state
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 🔒 MANDATORY: Execute use case and handle success
            let result = try await {USECASE_PROPERTY}.execute(input: input)
            
            // TODO: Handle success result based on specific UseCase requirements
            // Example: self.data = result
            data = result
            
        } catch {
            // 🔒 MANDATORY: Handle errors
            errorMessage = error.localizedDescription
        }
    }
}
```

## Architecture Compliance

This ViewModel UseCase execution implementation follows the Clean Architecture + SwiftUI pattern by:
- Using @MainActor to ensure UI updates on main thread
- Creating UseCase instances with dependency injection
- Using async/await for asynchronous operations
- Following the separation of concerns between ViewModel and UseCase layers
- Providing proper error handling and loading state management with @Published properties
- Using defer to ensure loading state is always reset

## Important Implementation Rules

### ❌ DO NOT DO THESE:
1. **NEVER forget @MainActor on ViewModel classes** - required for @Published properties
2. **NEVER use completion handlers** - always use async/await
3. **NEVER add complex error handling logic** - keep error handling simple
4. **NEVER forget defer for loading state** - ensures proper cleanup

### ✅ CORRECT PATTERNS:
```swift
// ✅ Correct ViewModel structure
@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let fetchUserUseCase: FetchUserUseCase
    
    init(fetchUserUseCase: FetchUserUseCase) {
        self.fetchUserUseCase = fetchUserUseCase
    }
    
    func loadProfile(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            profile = try await fetchUserUseCase.execute(input: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// ✅ Correct View usage
struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let profile = viewModel.profile {
                ProfileContent(profile: profile)
            }
        }
        .task {
            await viewModel.loadProfile(userId: "123")
        }
    }
}
```

## UseCase Property Naming

Common use case property names in ViewModels:
- **LoginViewModel**: `loginUseCase`
- **ProfileViewModel**: `fetchProfileUseCase`, `updateProfileUseCase`
- **SettingsViewModel**: `updateSettingsUseCase`
````
