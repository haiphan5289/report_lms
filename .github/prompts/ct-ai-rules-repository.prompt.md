````prompt
---
description: "Generate basic iOS Repository structure with async/await"
mode: "agent"
---

# iOS Basic Repository Generator

Generate basic Repository following Clean Architecture patterns with async/await.

## Instructions

Reference our iOS development guidelines: [iOS Guidelines](../instructions/ios-general-instructions.instructions.md)

Generate basic Repository structure with:

-   Protocol and implementation
-   Service dependency injection
-   async/await method signatures
-   TODO comments for implementation
-   Proper MARK sections

## Repository Template

```swift
import Foundation

protocol [Name]RepositoryType: AnyObject {
    // TODO: Define repository methods with async throws
    // func fetchData(
    //     parameter1: String?,
    //     parameter2: Int
    // ) async throws -> [SomeEntity]
    // 
    // func processData(
    //     data: SomeInput
    // ) async throws -> SomeOutput
    //
    // func updateData(
    //     id: String,
    //     data: SomeInput
    // ) async throws -> SomeEntity
}

final class [Name]Repository: [Name]RepositoryType {
    
    // MARK: - Properties
    
    private let service: [Name]ServiceType
    
    // MARK: - Initialization
    
    init(service: [Name]ServiceType) {
        self.service = service
    }
    
    // MARK: - [Name]RepositoryType
    
    // TODO: Implement repository methods
    // func fetchData(
    //     parameter1: String?,
    //     parameter2: Int
    // ) async throws -> [SomeEntity] {
    //     let models = try await service.fetchData(
    //         parameter1: parameter1,
    //         parameter2: parameter2
    //     )
    //     
    //     // Map models to entities
    //     return models.map { $0.toEntity() }
    // }
    //
    // func processData(data: SomeInput) async throws -> SomeOutput {
    //     let model = try await service.processData(data: data)
    //     return model.toEntity()
    // }
    //
    // func updateData(id: String, data: SomeInput) async throws -> SomeEntity {
    //     let model = try await service.updateData(id: id, data: data)
    //     return model.toEntity()
    // }
}
```

## Repository with Error Mapping

```swift
import Foundation

protocol [Name]RepositoryType: AnyObject {
    func fetchData() async throws -> [DataEntity]
}

final class [Name]Repository: [Name]RepositoryType {
    
    // MARK: - Properties
    
    private let service: [Name]ServiceType
    
    // MARK: - Initialization
    
    init(service: [Name]ServiceType) {
        self.service = service
    }
    
    // MARK: - [Name]RepositoryType
    
    func fetchData() async throws -> [DataEntity] {
        do {
            let models = try await service.fetchData()
            
            // Validate and transform
            guard !models.isEmpty else {
                throw AppError.invalidData
            }
            
            // Map to entities
            return models.enumerated().map { index, model in
                model.toEntity(index: index)
            }
        } catch let error as NetworkError {
            throw AppError.networkError(error)
        } catch {
            throw AppError.unknown(error)
        }
    }
}
```

## Repository with Caching

```swift
import Foundation

protocol [Name]RepositoryType: AnyObject {
    func fetchData(forceRefresh: Bool) async throws -> [DataEntity]
}

final class [Name]Repository: [Name]RepositoryType {
    
    // MARK: - Properties
    
    private let service: [Name]ServiceType
    private var cachedData: [DataEntity]?
    private var lastFetchDate: Date?
    
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    
    init(service: [Name]ServiceType) {
        self.service = service
    }
    
    // MARK: - [Name]RepositoryType
    
    func fetchData(forceRefresh: Bool = false) async throws -> [DataEntity] {
        // Check cache validity
        if !forceRefresh,
           let cached = cachedData,
           let lastFetch = lastFetchDate,
           Date().timeIntervalSince(lastFetch) < cacheExpirationInterval {
            return cached
        }
        
        // Fetch fresh data
        let models = try await service.fetchData()
        let entities = models.map { $0.toEntity() }
        
        // Update cache
        cachedData = entities
        lastFetchDate = Date()
        
        return entities
    }
}
```

## Template Variables

-   `${input:repositoryName}`: Repository name (e.g., "User", "Course", "Report")
-   `${input:feature}`: Feature module (e.g., "report_lms")
-   `${input:entityName}`: Entity type (e.g., "User", "Course")
-   `${input:operations}`: Comma-separated operations (e.g., "fetch,create,update,delete")

## Usage Examples

-   `/ios-repository repositoryName:User feature:report_lms entityName:User`
-   `/ios-repository repositoryName:Course feature:report_lms entityName:Course`

## Output

Generate basic Repository with:

1. Protocol definition with async method signatures
2. Implementation with service dependency
3. async/await patterns (no completion handlers)
4. TODO comments for implementation
5. Proper naming conventions
6. MARK sections for organization
7. Error handling patterns

Keep implementation minimal with TODO guidance for data operations.

````