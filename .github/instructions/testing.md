# Testing Strategy

## Use Case Testing

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
    
    override func tearDown() {
        sut = nil
        mockRepository = nil
        super.tearDown()
    }
    
    func testExecute_Success() async throws {
        // Given
        let expectedUser = User(id: "1", name: "Test", email: "test@example.com")
        mockRepository.mockUser = expectedUser
        
        // When
        let result = try await sut.execute(userId: "1")
        
        // Then
        XCTAssertEqual(result, expectedUser)
        XCTAssertTrue(mockRepository.fetchUserCalled)
    }
    
    func testExecute_Failure() async {
        // Given
        mockRepository.shouldThrowError = true
        
        // Then
        do {
            _ = try await sut.execute(userId: "1")
            XCTFail("Should throw error")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
```

## Mock Repository

```swift
// Mock Repository
final class MockUserRepository: UserRepositoryType {
    var mockUser: User?
    var shouldThrowError = false
    var fetchUserCalled = false
    
    func fetchUser(id: String) async throws -> User {
        fetchUserCalled = true
        
        if shouldThrowError {
            throw NSError(domain: "test", code: -1)
        }
        
        guard let user = mockUser else {
            throw AppError.notFound
        }
        
        return user
    }
}
```

## ViewModel Testing

```swift
// report_lmsTests/Presentation/ViewModels/UserProfileViewModelTests.swift
import XCTest
@testable import report_lms

@MainActor
final class UserProfileViewModelTests: XCTestCase {
    var sut: UserProfileViewModel!
    var mockUseCase: MockFetchUserUseCase!
    
    override func setUp() {
        super.setUp()
        mockUseCase = MockFetchUserUseCase()
        sut = UserProfileViewModel(fetchUserUseCase: mockUseCase)
    }
    
    override func tearDown() {
        sut = nil
        mockUseCase = nil
        super.tearDown()
    }
    
    func testLoadUser_Success() async {
        // Given
        let expectedUser = User(id: "1", name: "Test", email: "test@example.com")
        mockUseCase.mockUser = expectedUser
        
        // When
        await sut.loadUser(userId: "1")
        
        // Then
        XCTAssertEqual(sut.user, expectedUser)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }
    
    func testLoadUser_Failure() async {
        // Given
        mockUseCase.shouldThrowError = true
        
        // When
        await sut.loadUser(userId: "1")
        
        // Then
        XCTAssertNil(sut.user)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.errorMessage)
    }
    
    func testLoadUser_Loading() async {
        // Given
        let expectation = expectation(description: "Loading state")
        mockUseCase.delay = 0.5
        
        // When
        Task {
            await sut.loadUser(userId: "1")
            expectation.fulfill()
        }
        
        // Then
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        XCTAssertTrue(sut.isLoading)
        
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertFalse(sut.isLoading)
    }
}
```

## Mock Use Case

```swift
final class MockFetchUserUseCase: FetchUserUseCase {
    var mockUser: User?
    var shouldThrowError = false
    var executeCalled = false
    var delay: TimeInterval = 0
    
    init() {
        super.init(repository: MockUserRepository())
    }
    
    override func execute(userId: String) async throws -> User {
        executeCalled = true
        
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw AppError.networkError(NSError(domain: "test", code: -1))
        }
        
        guard let user = mockUser else {
            throw AppError.notFound
        }
        
        return user
    }
}
```

## Repository Testing

```swift
final class UserRepositoryTests: XCTestCase {
    var sut: UserRepository!
    var mockService: MockUserService!
    
    override func setUp() {
        super.setUp()
        mockService = MockUserService()
        sut = UserRepository(service: mockService)
    }
    
    func testFetchUser_Success() async throws {
        // Given
        let mockModel = UserModel(id: "1", name: "Test", email: "test@example.com")
        mockService.mockUserModel = mockModel
        
        // When
        let result = try await sut.fetchUser(id: "1")
        
        // Then
        XCTAssertEqual(result.id, mockModel.id)
        XCTAssertEqual(result.name, mockModel.name)
        XCTAssertEqual(result.email, mockModel.email)
    }
    
    func testFetchUser_MapsModelToEntity() async throws {
        // Given
        let mockModel = UserModel(id: "1", name: "Test", email: "test@example.com")
        mockService.mockUserModel = mockModel
        
        // When
        let result = try await sut.fetchUser(id: "1")
        
        // Then
        XCTAssertTrue(type(of: result) == User.self)
    }
}
```

## Entity Testing

```swift
final class UserTests: XCTestCase {
    func testUserEquality() {
        // Given
        let user1 = User(id: "1", name: "Test", email: "test@example.com")
        let user2 = User(id: "1", name: "Test", email: "test@example.com")
        let user3 = User(id: "2", name: "Other", email: "other@example.com")
        
        // Then
        XCTAssertEqual(user1, user2)
        XCTAssertNotEqual(user1, user3)
    }
    
    func testUserIdentifiable() {
        // Given
        let user = User(id: "123", name: "Test", email: "test@example.com")
        
        // Then
        XCTAssertEqual(user.id, "123")
    }
}
```

## SwiftUI View Testing

```swift
import XCTest
import SwiftUI
@testable import report_lms

final class UserProfileViewTests: XCTestCase {
    @MainActor
    func testViewInitialization() {
        // Given
        let viewModel = UserProfileViewModel(fetchUserUseCase: MockFetchUserUseCase())
        
        // When
        let view = UserProfileView(viewModel: viewModel)
        
        // Then
        XCTAssertNotNil(view)
    }
}
```

## Test Helpers

```swift
// TestHelpers/UserFactory.swift
enum UserFactory {
    static func makeUser(
        id: String = "1",
        name: String = "Test User",
        email: String = "test@example.com"
    ) -> User {
        User(id: id, name: name, email: email)
    }
    
    static func makeUsers(count: Int) -> [User] {
        (0..<count).map { index in
            makeUser(
                id: "\(index)",
                name: "User \(index)",
                email: "user\(index)@example.com"
            )
        }
    }
}
```

## Testing Best Practices

1. **Test One Thing**: Each test should verify one specific behavior
2. **Given-When-Then**: Structure tests clearly with setup, execution, and assertion
3. **Descriptive Names**: Use clear test names that describe what is being tested
4. **Independent Tests**: Tests should not depend on each other
5. **Mock External Dependencies**: Use mocks for network, databases, and other external systems
6. **Async Testing**: Use async/await for testing asynchronous code
7. **Clean Up**: Always clean up in tearDown() method

## Running Tests

```bash
# Run all tests
xcodebuild test -scheme report_lms -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test
xcodebuild test -scheme report_lms -only-testing:report_lmsTests/UserProfileViewModelTests

# Run tests in Xcode
Cmd+U
```

## Code Coverage

Enable code coverage in Xcode:
1. Edit Scheme
2. Test tab
3. Options → Code Coverage
4. Check "Gather coverage for all targets"

Target coverage: 80% or higher for business logic (Use Cases, ViewModels, Repositories)
