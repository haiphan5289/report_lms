# PDF Parameter Refactoring - Quick Reference Guide

## 🎯 Problem Summary

**Current Code:**
```swift
let data = try await generatePDFUseCase.execute(
    detail: detail,
    images: capturedPhotos,
    inspectorName: inspectorName,
    location: location
)
```

**Issues:**
- 4 separate parameters
- Hard to extend
- No validation
- Difficult to test

---

## 🏆 Recommended Solution: Builder Pattern

### Why Builder Pattern?

| Aspect | Rating | Notes |
|--------|--------|-------|
| **Simplicity** | ⭐⭐⭐⭐ | Moderate complexity |
| **Flexibility** | ⭐⭐⭐⭐⭐ | Excellent extensibility |
| **Performance** | ⭐⭐⭐⭐ | Minimal overhead |
| **Maintainability** | ⭐⭐⭐⭐⭐ | Easy to maintain |
| **Testability** | ⭐⭐⭐⭐⭐ | Excellent coverage |
| **Total Score** | **23/25** | **Best Overall** |

### Quick Implementation

```swift
// 1. Create request using builder
let request = try PDFReportRequestBuilder.withDefaults()
    .with(detail: detail)
    .with(images: capturedPhotos)
    .with(location: location)
    .build()

// 2. Execute
let data = try await generatePDFUseCase.execute(request: request)
```

---

## 📊 All Solutions Comparison

### Quick Decision Matrix

```
Need quick fix?                    → Solution 1 (DTO)
Need flexibility?                  → Solution 2 (Builder)
Need audit trail?                  → Solution 3 (Request-Response)
Need real-time config?             → Solution 4 (Context)
Follow DDD?                        → Solution 5 (Nested Models)
```

### Visual Comparison

```
Complexity vs Features

High Features │             ⬤ Solution 4 (Context)
             │       ⬤ Solution 3 (Request-Response)
             │    ⬤ Solution 5 (Nested)
             │  ⬤ Solution 2 (Builder) ← RECOMMENDED
Low Features │⬤ Solution 1 (DTO)
             └────────────────────────────────────
               Low            Complexity         High
```

---

## 🚀 Implementation Steps

### Phase 1: Add Models (30 min)

```bash
# Create these files:
Domain/Entities/PDFReportRequest.swift
Domain/Entities/PDFReportRequestBuilder.swift
Domain/UseCases/GenerateHTMLPDFReportUseCase+Solution1.swift
```

### Phase 2: Update ViewModel (15 min)

```swift
// In FinalReportViewModel.swift, replace:
func generateAndPreviewPDF() async {
    // OLD CODE
    let data = try await generatePDFUseCase.execute(
        detail: detail,
        images: capturedPhotos,
        inspectorName: inspectorName,
        location: location
    )
    
    // NEW CODE
    let request = try PDFReportRequestBuilder.withDefaults()
        .with(detail: detail)
        .with(images: capturedPhotos)
        .with(location: location)
        .build()
    
    let data = try await generatePDFUseCase.execute(request: request)
}
```

### Phase 3: Test (30 min)

```swift
// Add tests from PDFParameterRefactoringTests.swift
func testBuilder_BuildsSuccessfully() throws {
    let request = try PDFReportRequestBuilder()
        .with(detail: mockDetail)
        .with(images: mockImages)
        .with(inspectorName: "John")
        .with(location: "Factory A")
        .build()
    
    XCTAssertTrue(request.isValid)
}
```

---

## 📈 Before & After Comparison

### Code Metrics

| Metric | Before | After (Builder) | Change |
|--------|--------|-----------------|--------|
| Parameters | 4 | 1 | ✅ -75% |
| Lines to call | 5 | 5 | ➖ Same |
| Type safety | ⚠️ | ✅ | ✅ Better |
| Validation | ❌ | ✅ | ✅ Added |
| Extensibility | ⚠️ | ✅ | ✅ Much better |
| Test complexity | Medium | Easy | ✅ Improved |

### Error Handling

**Before:**
```swift
// No validation - errors only at runtime
let data = try await generatePDFUseCase.execute(...)
```

**After:**
```swift
// Validation at build time
do {
    let request = try builder.build() // ← Validates here
    let data = try await useCase.execute(request: request)
} catch let error as PDFReportBuilderError {
    // Handle validation errors
} catch {
    // Handle generation errors
}
```

---

## 🎓 Code Examples by Scenario

### Scenario 1: Standard PDF Generation

```swift
func generatePDF() async {
    guard let detail = inspectionDetail else { return }
    
    do {
        let request = try PDFReportRequestBuilder.withDefaults()
            .with(detail: detail)
            .with(images: capturedPhotos)
            .with(location: location)
            .build()
        
        pdfData = try await generatePDFUseCase.execute(request: request)
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

### Scenario 2: PDF Without Photos

```swift
let request = try PDFReportRequestBuilder.withDefaults()
    .with(detail: detail)
    .with(images: [:]) // Empty images
    .with(location: location)
    .build()
```

### Scenario 3: Custom Inspector Name

```swift
let request = try PDFReportRequestBuilder()
    .with(detail: detail)
    .with(images: capturedPhotos)
    .with(inspectorName: "Custom Inspector")
    .with(location: location)
    .build()
```

### Scenario 4: Reusable Builder

```swift
// Create base builder
let baseBuilder = PDFReportRequestBuilder.withDefaults()
    .with(detail: detail)
    .with(images: capturedPhotos)

// Use for different locations
let request1 = try baseBuilder.with(location: "Factory A").build()
let request2 = try baseBuilder.with(location: "Factory B").build()
```

---

## 🧪 Testing Guide

### Unit Test Template

```swift
func testMyPDFGeneration() throws {
    // Given
    let builder = PDFReportRequestBuilder()
        .with(detail: mockDetail)
        .with(images: mockImages)
        .with(inspectorName: "Test Inspector")
        .with(location: "Test Location")
    
    // When
    let request = try builder.build()
    
    // Then
    XCTAssertTrue(request.isValid)
    XCTAssertEqual(request.inspectorName, "Test Inspector")
}
```

### Mock Data

```swift
let mockRequest = PDFReportRequest(
    inspectionDetail: .mock(),
    capturedImages: [:],
    inspectorName: "Mock Inspector",
    inspectionLocation: "Mock Location"
)
```

---

## ⚠️ Common Pitfalls & Solutions

### Pitfall 1: Forgetting to Call build()

```swift
// ❌ WRONG - Returns builder, not request
let request = PDFReportRequestBuilder()
    .with(detail: detail)
    .with(images: images)

// ✅ CORRECT
let request = try PDFReportRequestBuilder()
    .with(detail: detail)
    .with(images: images)
    .build() // ← Don't forget!
```

### Pitfall 2: Not Handling Builder Errors

```swift
// ❌ WRONG - Unhandled error
let request = try! builder.build() // Dangerous!

// ✅ CORRECT
do {
    let request = try builder.build()
} catch let error as PDFReportBuilderError {
    logger.error("Validation failed: \(error)")
}
```

### Pitfall 3: Reusing Builder Without Reset

```swift
// ❌ WRONG - State leaks between uses
let builder = PDFReportRequestBuilder()
let req1 = try builder.with(detail: detail1).build()
let req2 = try builder.with(detail: detail2).build() // Still has detail1!

// ✅ CORRECT
let req1 = try builder.with(detail: detail1).build()
builder.reset()
let req2 = try builder.with(detail: detail2).build()
```

---

## 📚 Additional Resources

### Files Created

1. `PDFReportRequest.swift` - DTO model
2. `PDFReportRequestBuilder.swift` - Builder implementation
3. `GenerateHTMLPDFReportUseCase+Solution1.swift` - Use case extension
4. `FinalReportViewModel+BuilderImplementation.swift` - ViewModel example
5. `PDFParameterRefactoringTests.swift` - Comprehensive tests
6. `ALTERNATIVE_APPROACHES_PDF_REFACTORING.md` - Full analysis

### Key Concepts

- **DTO (Data Transfer Object)**: Simple data container
- **Builder Pattern**: Step-by-step object construction
- **Fluent API**: Method chaining (`.with().with().build()`)
- **Validation**: Built-in error checking
- **Type Safety**: Compile-time guarantees

---

## 🎬 Quick Start Checklist

- [ ] Read full analysis document
- [ ] Add PDFReportRequest.swift to project
- [ ] Add PDFReportRequestBuilder.swift to project  
- [ ] Add use case extension
- [ ] Update FinalReportViewModel
- [ ] Run unit tests
- [ ] Test in simulator
- [ ] Code review
- [ ] Deploy to staging
- [ ] Monitor for issues
- [ ] Remove old implementation

---

## 💡 Pro Tips

1. **Start Simple**: Use Solution 1 (DTO) first if time is critical
2. **Iterate**: Upgrade to Builder later when needed
3. **Test First**: Write tests before implementing
4. **Document**: Add clear comments for team
5. **Monitor**: Track performance after deployment

---

## 🆘 Need Help?

**Quick Links:**
- 📄 Full Analysis: `ALTERNATIVE_APPROACHES_PDF_REFACTORING.md`
- 🧪 Tests: `PDFParameterRefactoringTests.swift`
- 💻 Implementation: `FinalReportViewModel+BuilderImplementation.swift`

**Decision Not Clear?**
1. Quick fix needed? → Solution 1
2. Default choice → Solution 2 (Builder)
3. Enterprise app? → Solution 3
4. Complex config? → Solution 4
5. DDD project? → Solution 5

---

*Generated for report_lms iOS Application*  
*Clean Architecture + SwiftUI Pattern*  
*Date: March 6, 2026*
