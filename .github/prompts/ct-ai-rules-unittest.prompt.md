````prompt
---
description: "Generate iOS unit test structure using XCTest"
mode: "agent"
---

# iOS Unit Test Generator

Generate unit test structure following XCTest patterns with mock generation for SwiftUI + Clean Architecture.

## Instructions

Reference our iOS development guidelines: [iOS Guidelines](../instructions/ios-general-instructions.instructions.md)

Generate unit test structure with:

-   XCTest testing framework
-   Mock classes for all dependencies
-   Test structure with proper setup and teardown
-   BDD-style test organization (Given-When-Then)
-   Proper imports and test configuration

## Test Class Template

```swift
import XCTest
@testable import report_lms

@MainActor
final class [TestClassName]Tests: XCTestCase {
    var sut: [ClassUnderTest]!
    var mockRepository: Mock[Repository]!
    // TODO: Add other mock dependencies
    // var mockUseCase: Mock[UseCase]!
    
    override func setUp() {
        super.setUp()
        
        // TODO: Initialize mock dependencies
        mockRepository = Mock[Repository]()
        
        // TODO: Initialize system under test with dependencies
        sut = [ClassUnderTest](
            // TODO: Add constructor parameters
            // repository: mockRepository,
            // useCase: mockUseCase
        )
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        // TODO: Clean up other mocks
        super.tearDown()
    }
    
    func test_initialization_setsInitialState() {
        // Given/When - from setUp
        
        // Then
        XCTAssertNotNil(sut)
        // TODO: Add initialization assertions
    }
    
    // TODO: Add more test methods following Given-When-Then pattern
    func test_specificAction_expectedBehavior() async {
        // Given
        // Setup test conditions
        
        // When
        // Execute action
        
        // Then
        // Verify results
    }
}
```

## Mock Repository Template

```swift
import Foundation

@testable import report_lms

final class Mock[RepositoryName]: [RepositoryName]Type {
    // MARK: - Method Tracking
    var methodNameCalled = false
    var methodNameCallCount = 0
    var methodNameParameters: [ParameterType]?
    var methodNameResult: Result<[ReturnType], Error>!
    
    func methodName(parameter: [ParameterType]) async throws -> [ReturnType] {
        methodNameCalled = true
        methodNameCallCount += 1
        methodNameParameters = parameter
        
        switch methodNameResult {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        case .none:
            fatalError("methodNameResult not set")
        }
    }
    
    // TODO: Add more repository methods following the same pattern
}
```

## Mock Use Case Template

```swift
import Foundation

@testable import report_lms

final class Mock[UseCaseName]: [UseCaseName]Type {
    // MARK: - Execute Method Tracking
    var executeCalled = false
    var executeCallCount = 0
    var executeInput: [InputType]?
    var executeResult: Result<[OutputType], Error>!
    
    func execute(input: [InputType]) async throws -> [OutputType] {
        executeCalled = true
        executeCallCount += 1
        executeInput = input
        
        switch executeResult {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        case .none:
            fatalError("executeResult not set")
        }
    }
}
```

## ViewModel Test Template

```swift
import XCTest
@testable import report_lms

@MainActor
final class [ViewModel]Tests: XCTestCase {
    var sut: [ViewModel]!
    var mockUseCase: Mock[UseCase]!
    
    override func setUp() {
        super.setUp()
        mockUseCase = Mock[UseCase]()
        sut = [ViewModel](useCase: mockUseCase)
    }
    
    override func tearDown() {
        sut = nil
        mockUseCase = nil
        super.tearDown()
    }
    
    func test_loadData_success_updatesPublishedProperties() async {
        // Given
        let expectedData = [DataModel].mock()
        mockUseCase.executeResult = .success(expectedData)
        
        // When
        await sut.loadData()
        
        // Then
        XCTAssertEqual(sut.data, expectedData)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertTrue(mockUseCase.executeCalled)
    }
    
    func test_loadData_failure_setsErrorMessage() async {
        // Given
        let expectedError = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        mockUseCase.executeResult = .failure(expectedError)
        
        // When
        await sut.loadData()
        
        // Then
        XCTAssertNil(sut.data)
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.errorMessage, "Test error")
        XCTAssertTrue(mockUseCase.executeCalled)
    }
    
    func test_loadData_setsLoadingState() async {
        // Given
        mockUseCase.executeResult = .success([DataModel].mock())
        
        // When
        let expectation = expectation(description: "Loading state")
        Task {
            await sut.loadData()
            expectation.fulfill()
        }
        
        // Then - Check loading state during execution
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        XCTAssertTrue(sut.isLoading)
        
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(sut.isLoading)
    }
}
```

## Use Case Test Template

```swift
import XCTest
@testable import report_lms

final class [UseCase]Tests: XCTestCase {
    var sut: [UseCase]!
    var mockRepository: Mock[Repository]!
    
    override func setUp() {
        super.setUp()
        mockRepository = Mock[Repository]()
        sut = [UseCase](repository: mockRepository)
    }
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }
    
    func test_execute_success_returnsExpectedData() async throws {
        // Given
        let expectedData = [DataModel].mock()
        mockRepository.fetchDataResult = .success(expectedData)
        let input = "test-input"
        
        // When
        let result = try await sut.execute(input: input)
        
        // Then
        XCTAssertEqual(result, expectedData)
        XCTAssertTrue(mockRepository.fetchDataCalled)
        XCTAssertEqual(mockRepository.fetchDataParameters, input)
    }
    
    func test_execute_failure_throwsError() async {
        // Given
        let expectedError = NSError(domain: "test", code: -1)
        mockRepository.fetchDataResult = .failure(expectedError)
        
        // Then
        do {
            _ = try await sut.execute(input: "test")
            XCTFail("Should throw error")
        } catch {
            XCTAssertNotNil(error)
            XCTAssertTrue(mockRepository.fetchDataCalled)
        }
    }
}
```

## Repository Test Template

```swift
import XCTest
@testable import report_lms

final class [Repository]Tests: XCTestCase {
    var sut: [Repository]!
    var mockService: Mock[Service]!
    
    override func setUp() {
        super.setUp()
        mockService = Mock[Service]()
        sut = [Repository](service: mockService)
    }
    
    override func tearDown() {
        sut = nil
        mockService = nil
        super.tearDown()
    }
    
    func test_fetchData_success_returnsEntity() async throws {
        // Given
        let mockModel = [DataModel].mock()
        mockService.getDataResult = .success(mockModel)
        
        // When
        let result = try await sut.fetchData()
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(mockService.getDataCalled)
        // Verify model to entity mapping
        XCTAssertEqual(result.id, mockModel.id)
    }
    
    func test_fetchData_failure_throwsError() async {
        // Given
        let expectedError = NSError(domain: "test", code: -1)
        mockService.getDataResult = .failure(expectedError)
        
        // Then
        do {
            _ = try await sut.fetchData()
            XCTFail("Should throw error")
        } catch {
            XCTAssertNotNil(error)
            XCTAssertTrue(mockService.getDataCalled)
        }
    }
}
```

## Template Variables

-   `${input:className}`: Class name being tested (e.g., "UserProfileViewModel")
-   `${input:feature}`: Feature module (e.g., "UserManagement")
-   `${input:testType}`: Test type: "viewModel", "useCase", "repository"

## Usage Examples

-   `/ios-unittest className:UserProfileViewModel feature:UserManagement testType:viewModel`
-   `/ios-unittest className:GetUserUseCase feature:UserManagement testType:useCase`
-   `/ios-unittest className:UserRepository feature:UserManagement testType:repository`

## Test Organization Best Practices

### 1. Given-When-Then Pattern

```swift
func test_login_success_updatesUserSession() async {
    // Given
    let expectedUser = User.mock()
    mockUseCase.executeResult = .success(expectedUser)
    
    // When
    await sut.login(email: "test@example.com", password: "password")
    
    // Then
    XCTAssertEqual(sut.user, expectedUser)
    XCTAssertFalse(sut.isLoading)
    XCTAssertNil(sut.errorMessage)
}
```

### 2. Test Naming Convention

```swift
// Pattern: test_methodName_condition_expectedBehavior
func test_loadUser_success_updatesUserProperty() async { }
func test_loadUser_failure_setsErrorMessage() async { }
func test_loadUser_emptyResponse_handlesGracefully() async { }
```

### 3. Mock Verification

```swift
func test_saveSettings_callsRepositoryWithCorrectParameters() async throws {
    // Given
    let settings = Settings.mock()
    mockRepository.saveSettingsResult = .success(())
    
    // When
    try await sut.saveSettings(settings)
    
    // Then
    XCTAssertTrue(mockRepository.saveSettingsCalled)
    XCTAssertEqual(mockRepository.saveSettingsParameters, settings)
}
```

### 4. Async Testing

```swift
// Test async operations with async/await
func test_asyncOperation() async throws {
    let result = try await sut.performAsyncOperation()
    XCTAssertNotNil(result)
}

// Test loading states with expectations
func test_loadingState() async {
    let expectation = expectation(description: "Loading completes")
    
    Task {
        await sut.loadData()
        expectation.fulfill()
    }
    
    // Check intermediate state
    try? await Task.sleep(nanoseconds: 100_000_000)
    XCTAssertTrue(sut.isLoading)
    
    await fulfillment(of: [expectation], timeout: 1.0)
    XCTAssertFalse(sut.isLoading)
}
```

## Mock Factories

```swift
// Create mock factory extensions for test data
extension User {
    static func mock(
        id: String = "123",
        name: String = "Test User",
        email: String = "test@example.com"
    ) -> User {
        User(id: id, name: name, email: email)
    }
}

extension Array where Element == User {
    static func mock(count: Int = 3) -> [User] {
        (0..<count).map { User.mock(id: "\($0)") }
    }
}
```

## Output

Generate unit test with:

1. XCTest test structure with @MainActor where needed
2. Mock classes for all dependencies using async/await
3. Proper setUp and tearDown methods
4. Given-When-Then test organization
5. TODO comments for test implementation
6. Proper import statements
7. Mock verification patterns
8. Async/await support

Keep tests focused on behavior verification following Clean Architecture + SwiftUI patterns.

````
