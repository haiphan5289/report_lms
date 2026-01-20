````prompt
---
description: "Generate basic iOS Service structure with async/await"
mode: "agent"
---

# iOS Basic Service Generator

Generate basic Service following Clean Architecture patterns and API integration with async/await.

## Instructions

Reference our iOS development guidelines: [iOS Guidelines](../instructions/ct-ai-rules-general-instructions.instructions.md)

Generate basic Service structure with:

-   Protocol and implementation
-   URLSession or custom API client integration
-   async/await patterns
-   Proper error handling
-   TODO comments for implementation
-   Proper MARK sections

## Service Template

```swift
import Foundation

protocol [Name]ServiceType {
    // TODO: Define service methods with async throws
    // func fetchData(parameter: String) async throws -> [SomeModel]
    // func submitData(_ data: SomeInputModel) async throws -> SomeResponseModel
    // func updateData(id: String, data: SomeInputModel) async throws -> SomeResponseModel
    // func deleteData(id: String) async throws -> Bool
}

final class [Name]Service: [Name]ServiceType {
    
    // MARK: - Properties
    
    private let session: URLSession
    private let baseURL: URL
    
    // MARK: - Initialization
    
    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.example.com")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }
    
    // MARK: - [Name]ServiceType
    
    // TODO: Implement service methods
    // func fetchData(parameter: String) async throws -> [SomeModel] {
    //     let url = baseURL.appendingPathComponent("data")
    //         .appending(queryItems: [URLQueryItem(name: "param", value: parameter)])
    //     
    //     let (data, response) = try await session.data(from: url)
    //     
    //     guard let httpResponse = response as? HTTPURLResponse,
    //           (200...299).contains(httpResponse.statusCode) else {
    //         throw NetworkError.invalidResponse
    //     }
    //     
    //     return try JSONDecoder().decode([SomeModel].self, from: data)
    // }
    //
    // func submitData(_ data: SomeInputModel) async throws -> SomeResponseModel {
    //     let url = baseURL.appendingPathComponent("submit")
    //     var request = URLRequest(url: url)
    //     request.httpMethod = "POST"
    //     request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    //     request.httpBody = try JSONEncoder().encode(data)
    //     
    //     let (responseData, response) = try await session.data(for: request)
    //     
    //     guard let httpResponse = response as? HTTPURLResponse,
    //           (200...299).contains(httpResponse.statusCode) else {
    //         throw NetworkError.invalidResponse
    //     }
    //     
    //     return try JSONDecoder().decode(SomeResponseModel.self, from: responseData)
    // }
    //
    // func deleteData(id: String) async throws -> Bool {
    //     let url = baseURL.appendingPathComponent("data/\(id)")
    //     var request = URLRequest(url: url)
    //     request.httpMethod = "DELETE"
    //     
    //     let (_, response) = try await session.data(for: request)
    //     
    //     guard let httpResponse = response as? HTTPURLResponse,
    //           (200...299).contains(httpResponse.statusCode) else {
    //         return false
    //     }
    //     
    //     return true
    // }
}
```

## Advanced Service with Error Handling

```swift
import Foundation

protocol [Name]ServiceType {
    func fetchConfiguredData(categoryId: String, type: String) async throws -> ConfigModel
    func processComplexRequest(params: [String: Any]) async throws -> [ProcessedModel]
}

final class [Name]Service: [Name]ServiceType {
    
    // MARK: - Properties
    
    private let session: URLSession
    private let baseURL: URL
    
    enum ServiceError: LocalizedError {
        case invalidURL
        case noData
        case invalidConfiguration(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .noData:
                return "No data received"
            case .invalidConfiguration(let type):
                return "Invalid configuration for type: \(type)"
            }
        }
    }
    
    // MARK: - Initialization
    
    init(
        session: URLSession = .shared,
        baseURL: URL
    ) {
        self.session = session
        self.baseURL = baseURL
    }
    
    // MARK: - [Name]ServiceType
    
    func fetchConfiguredData(categoryId: String, type: String) async throws -> ConfigModel {
        let url = baseURL.appendingPathComponent("config/\(categoryId)")
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        
        let configResponse = try JSONDecoder().decode([String: ConfigModel].self, from: data)
        
        guard let config = configResponse[type] else {
            throw ServiceError.invalidConfiguration(type)
        }
        
        return config
    }
    
    func processComplexRequest(params: [String: Any]) async throws -> [ProcessedModel] {
        let url = baseURL.appendingPathComponent("process")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: params)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.invalidResponse
        }
        
        return try JSONDecoder().decode([ProcessedModel].self, from: data)
    }
}
```

## Service with Multiple Endpoints

```swift
import Foundation

protocol [Name]ServiceType {
    func fetchCategories() async throws -> [CategoryModel]
    func searchSuggestions(query: String, filters: [String]) async throws -> [SuggestionModel]
    func analyzeText(content: String) async throws -> AnalysisResult
    func checkLimits(userId: String, category: String) async throws -> LimitResponse
}

final class [Name]Service: [Name]ServiceType {
    
    // MARK: - Properties
    
    private let session: URLSession
    private let baseURL: URL
    
    // MARK: - Initialization
    
    init(
        session: URLSession = .shared,
        baseURL: URL
    ) {
        self.session = session
        self.baseURL = baseURL
    }
    
    // MARK: - [Name]ServiceType
    
    func fetchCategories() async throws -> [CategoryModel] {
        let url = baseURL.appendingPathComponent("categories")
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([CategoryModel].self, from: data)
    }
    
    func searchSuggestions(query: String, filters: [String]) async throws -> [SuggestionModel] {
        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: true)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "filters", value: filters.joined(separator: ","))
        ]
        
        guard let url = components.url else {
            throw ServiceError.invalidURL
        }
        
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([SuggestionModel].self, from: data)
    }
    
    func analyzeText(content: String) async throws -> AnalysisResult {
        let url = baseURL.appendingPathComponent("analyze")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["content": content])
        
        let (data, _) = try await session.data(for: request)
        return try JSONDecoder().decode(AnalysisResult.self, from: data)
    }
    
    func checkLimits(userId: String, category: String) async throws -> LimitResponse {
        let url = baseURL
            .appendingPathComponent("limits")
            .appendingPathComponent(userId)
            .appending(queryItems: [URLQueryItem(name: "category", value: category)])
        
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(LimitResponse.self, from: data)
    }
}
```

## Best Practices

### Required Patterns

1. **Protocol Definition**: Always define a protocol for your service
2. **async/await**: All methods must use async throws (no completion handlers)
3. **Error Handling**: Implement proper error mapping and validation
4. **URLSession**: Use URLSession for network requests
5. **Codable**: Use Codable for JSON encoding/decoding

### Naming Conventions

-   **Protocol**: `[Name]ServiceType`
-   **Implementation**: `[Name]Service`
-   **Methods**: Use descriptive verbs (fetch, submit, update, delete, check, analyze)

### Import Requirements

```swift
import Foundation
```

### Error Handling Patterns

```swift
// Check HTTP status
guard let httpResponse = response as? HTTPURLResponse,
      (200...299).contains(httpResponse.statusCode) else {
    throw NetworkError.invalidResponse
}

// Validate data
guard !data.isEmpty else {
    throw ServiceError.noData
}

// Custom validation
guard let result = response.data else {
    throw ServiceError.invalidConfiguration("missing data")
}
```

## Template Variables

-   `${input:serviceName}`: Service name (e.g., "User", "Course", "Report")
-   `${input:feature}`: Feature module (e.g., "report_lms")
-   `${input:operations}`: Comma-separated operations (e.g., "fetch,submit,update,delete")
-   `${input:entityName}`: Entity type (e.g., "User", "Course", "Report")

## Usage Examples

-   `/ios-service serviceName:User feature:report_lms operations:fetch,update entityName:User`
-   `/ios-service serviceName:Course feature:report_lms operations:fetch,create,delete entityName:Course`
-   `/ios-service serviceName:Report feature:report_lms operations:fetch,submit entityName:Report`

## Output

Generate basic Service with:

1. Protocol definition with async method signatures
2. Service implementation with URLSession
3. Proper async/await patterns
4. Error handling patterns
5. TODO comments for implementation
6. Proper MARK sections
7. Codable integration

Keep implementation minimal with TODO guidance for specific business logic.

````