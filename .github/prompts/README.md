@@ -0,0 +1,230 @@
# iOS Scaffolding Guide

This guide explains how to use the iOS prompt files to generate code scaffolding for your Clean Architecture + SwiftUI project.

## Available Prompts

### 1. **component-creation-pattern.prompt.md** - UI Component Creation
Generate reusable SwiftUI components with proper styling and theming.

### 2. **ct-ai-chain-of-thought-pattern.prompt.md** - Technical Design Analysis
Analyze complex technical problems with step-by-step reasoning.

### 3. **ct-ai-rules-module.prompt.md** - Complete Feature Module Generation
Generate complete Clean Architecture modules with View, ViewModel, and dependencies.

### 4. **ct-ai-rules-usecase.prompt.md** - UseCase Generation
Generate Clean Architecture use cases with repository dependencies.

### 5. **ct-ai-rules-repository.prompt.md** - Repository Generation
Generate repositories with service layer integration.

### 6. **ct-ai-rules-service.prompt.md** - Service Layer Generation
Generate service layer for API integration.

### 7. **ct-ai-rules-unittest.prompt.md** - Unit Test Generation
Generate unit tests using XCTest with mock classes.

## How to Use Prompts

### Method 1: GitHub Copilot Chat Commands

Use natural language with context in GitHub Copilot Chat:

```
Create a student profile view following Clean Architecture
Generate a course enrollment use case with repository pattern
Create a reusable button component for the LMS
Build a complete report generation feature module
Generate unit tests for CourseViewModel
```

### Method 2: Reference Prompt Patterns

Reference specific prompt patterns for guidance:

```
Follow the component-creation-pattern to create a custom chart component
Use chain-of-thought-pattern to analyze the video player feature
Apply the rules-module pattern for the assignment submission feature
```

## Template Variables

All prompts support these concepts:

- **Feature Name** - Module name (e.g., "Login", "CourseList", "StudentProfile")
- **Entity Name** - Domain entity (e.g., "User", "Course", "Assignment")
- **Component Type** - SwiftUI view type (Button, TextField, Card, etc.)
- **Use Case Type** - Business logic operation (Fetch, Create, Update, Delete)

## Usage Examples

### Complete Feature Development Flow

1. **Define Domain Layer**:
```
Create a Course entity with id, title, description, and enrollment status
Generate a CourseRepositoryType protocol
Create a FetchCourseUseCase with repository dependency
```

2. **Implement Data Layer**:
```
Create a CourseModel with Codable conformance
Generate CourseService for API integration
Implement CourseRepository following the protocol
```

3. **Build Presentation Layer**:
```
Create CourseListViewModel with async data loading
Build CourseListView with List and navigation
Add LMSButton for enrollment action
```

4. **Add Tests**:
```
Generate XCTest suite for FetchCourseUseCase
Create mock CourseRepository for testing
Test CourseListViewModel with async expectations
```

### Individual File Generation

**SwiftUI View**:
```
Create a StudentProfileView using SwiftUI
```

**ViewModel**:
```
Generate a StudentProfileViewModel with @MainActor
```

**Use Case**:
```
Create an EnrollStudentUseCase with async/await
```

**Unit Test**:
```
Generate XCTest for StudentProfileViewModel
```

## Project Structure

Generated files should be organized in your project like this:

```
report_lms/
├── Sources/
│   ├── Domain/
│   │   ├── Entities/
│   │   │   ├── Student.swift
│   │   │   └── Course.swift
│   │   ├── Repositories/
│   │   │   ├── StudentRepositoryType.swift
│   │   │   └── CourseRepositoryType.swift
│   │   └── UseCases/
│   │       ├── FetchStudentUseCase.swift
│   │       └── EnrollCourseUseCase.swift
│   ├── Data/
│   │   ├── Models/
│   │   │   ├── StudentModel.swift
│   │   │   └── CourseModel.swift
│   │   ├── Repositories/
│   │   │   ├── StudentRepository.swift
│   │   │   └── CourseRepository.swift
│   │   └── Services/
│   │       ├── StudentService.swift
│   │       └── CourseService.swift
│   ├── Presentation/
│   │   └── Modules/
│   │       ├── StudentProfile/
│   │       │   ├── ViewModels/
│   │       │   │   └── StudentProfileViewModel.swift
│   │       │   └── Views/
│   │       │       └── StudentProfileView.swift
│   │       └── CourseList/
│   │           ├── ViewModels/
│   │           │   └── CourseListViewModel.swift
│   │           └── Views/
│   │               └── CourseListView.swift
│   └── Common/
│       └── Components/
│           ├── Buttons/
│           │   └── LMSButton.swift
│           ├── Text/
│           │   └── LMSLabel.swift
│           └── TextFields/
│               └── LMSTextField.swift
└── report_lmsTests/
    ├── Domain/
    │   └── UseCases/
    │       └── FetchStudentUseCaseTests.swift
    └── Presentation/
        └── ViewModels/
            └── StudentProfileViewModelTests.swift
```

## Best Practices

### 1. **Follow Naming Conventions**
- Use PascalCase for types: `StudentProfileView`, `CourseListViewModel`
- Use descriptive names: `FetchStudentUseCase` instead of `StudentUseCase`
- Prefix custom components with `LMS`: `LMSButton`, `LMSTextField`

### 2. **Generate in Order**
1. Domain Layer (Entities, Repository protocols, Use Cases)
2. Data Layer (Models, Services, Repository implementations)
3. Presentation Layer (ViewModels, Views)
4. Common Components (Reusable UI components)
5. Unit Tests (After implementation)

### 3. **Customize After Generation**
- Replace placeholder types with actual models
- Implement business logic in Use Cases
- Add proper error handling
- Ensure proper state management with @Published properties

### 4. **Use Native SwiftUI**
- Always use native SwiftUI components first
- Create custom LMS components for reusability
- Follow SwiftUI declarative patterns
- Use @MainActor for ViewModels

## Common Commands Reference

### Quick Module Setup
```
Create a complete CourseList module with Clean Architecture
- Generate Course entity and repository protocol
- Create FetchCoursesUseCase
- Build CourseListViewModel with async data loading
- Create CourseListView with List and navigation
```

### API Integration Setup
```
Set up course enrollment API integration
- Create CourseService with URLSession
- Implement CourseRepository
- Generate EnrollCourseUseCase
- Add enrollment action to ViewModel
```

### UI Component Setup
```
Create reusable LMS components
- LMSProgressBar for course progress
- LMSCourseCard for course display
- LMSEnrollButton with loading state
```

## Troubleshooting

### Common Issues

1. **Architecture confusion**: Follow the three-layer pattern (Presentation → Domain ← Data)

2. **State management**: Use @Published in ViewModels, @State/@StateObject in Views

3. **Async operations**: Always use async/await with proper error handling

4. **Component reusability**: Create custom LMS components in Common/Components/

### Getting Help

- Reference architecture.md in `.github/instructions/`
- Check code-standards.md for naming and organization
- Review code-style.md for SwiftUI best practices  
- Use component-creation-pattern.prompt.md for UI components

## Tips

- Start with Domain layer (entities and protocols) before implementation
- Use @MainActor for all ViewModels
- Always provide Preview configurations for SwiftUI views
- Test Use Cases and ViewModels with XCTest
- Follow Clean Architecture principles: Domain has no dependencies
- Use async/await instead of completion handlers
- Leverage SwiftUI's declarative nature for clean, readable code
