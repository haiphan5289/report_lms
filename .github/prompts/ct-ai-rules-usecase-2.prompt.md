````prompt
---
mode: agent
description: Generate UseCase classes following Clean Architecture + SwiftUI pattern for iOS application
---

# UseCase Generation Guide

## Overview
This guide provides instructions for adding UseCase classes to the iOS application following the Clean Architecture + SwiftUI pattern.

## Task Definition
Define the task to achieve UseCase generation, including specific requirements, constraints, and success criteria.

## Required Parameters

When generating a UseCase, you need to provide the following parameters:

- `{USECASE_NAME}`: The name of the UseCase (e.g., FetchUserProfile, UpdateSettings)
- `{INPUT_PARAM}`: The input parameter type for the UseCase (e.g., String, UserRequest)
- `{RESPONSE_MODEL}`: The response model type returned by the UseCase (e.g., User, Profile)
- `{REPOSITORY_CLASS}`: The repository class name that the UseCase will depend on (e.g., UserRepository)
- `{USECASE_CLASS}`: The UseCase class file name where the new UseCase will be added

## Add UseCase Implementation

Add the following UseCase implementation to {USECASE_CLASS}.swift file:

```swift
// Add to Domain/UseCases/{USECASE_CLASS}.swift file
final class {USECASE_NAME}UseCase {
    private let repository: {REPOSITORY_CLASS}Type
    
    init(repository: {REPOSITORY_CLASS}Type) {
        self.repository = repository
    }
    
    func execute(input: {INPUT_PARAM}) async throws -> {RESPONSE_MODEL} {
        try await repository.{USECASE_NAME}(input: input)
    }
}
```

## Architecture Compliance

This UseCase implementation follows the Clean Architecture + SwiftUI pattern by:
- Using protocol-based dependency injection for the repository
- Implementing async/await for asynchronous operations
- Encapsulating business logic within the execute method
- Maintaining proper separation of concerns between layers
- Following Swift concurrency best practices
````
