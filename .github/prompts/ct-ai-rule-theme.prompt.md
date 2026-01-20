# Theme Best Practices for iOS Swift SwiftUI - report_lms

## Overview

Hướng dẫn best practices cho việc sử dụng theme system trong iOS Swift SwiftUI dựa trên chuẩn mới nhất và architecture của report_lms app.

## Core Theme Architecture

### 1. Theme System Structure

```swift
// Theme hierarchy trong project
Sources/
├── Common/
│   ├── Theme/
│   │   ├── AppTheme.swift           // Theme protocol và structure
│   │   ├── ThemeType.swift          // Enum các loại theme
│   │   └── ThemeEnvironmentKey.swift // Environment key cho theme
│   └── Extensions/
│       └── EnvironmentValues+Theme.swift // Environment values extension
```

### 2. Theme Types Available

```swift
// Các theme types hiện có
public enum ThemeType {
    case `default`  // Theme chính của LMS
    case learning   // Theme cho Learning module
    case assessment // Theme cho Assessment module
}
```

## Essential Patterns

### 1. Theme Access with Environment (Recommended)

```swift
// ✅ PREFERRED - Sử dụng Environment for theme access
import SwiftUI

struct MyView: View {
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        VStack {
            Text("Title")
                .foregroundColor(theme.text.primary)
                .font(.title2)
        }
        .background(theme.background.primary)
    }
}
```

### 2. Dynamic Theme Support with @AppStorage

```swift
// ✅ Cho Views cần dynamic theme switching
import SwiftUI

struct MyView: View {
    @AppStorage("selectedTheme") private var selectedTheme: ThemeType = .default
    
    var body: some View {
        VStack {
            Text("Title")
                .font(.title2)
                .foregroundColor(currentTheme.text.primary)
            
            Text("Subtitle")
                .font(.caption)
                .foregroundColor(currentTheme.text.secondary)
        }
        .background(currentTheme.background.primary)
    }
    
    private var currentTheme: AppTheme {
        AppTheme.theme(for: selectedTheme)
    }
}
```

### 3. Reusable Component Theming

```swift
// ✅ Theme setup cho custom components
import SwiftUI

struct MyCard: View {
    @Environment(\.appTheme) private var theme
    
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(theme.text.primary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(theme.text.secondary)
        }
        .padding()
        .background(theme.background.secondary)
        .cornerRadius(8)
    }
}
```

### 4. Module-Specific Theme Usage

```swift
// ✅ Theme specific cho module Assessment
struct AssessmentView: View {
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Assessment")
                    .font(.largeTitle)
                    .foregroundColor(theme.text.primary)
            }
            .background(theme.background.brand)
            .navigationBarTitleDisplayMode(.inline)
        }
        .environment(\.appTheme, AppTheme.theme(for: .assessment))
    }
}

// ✅ Theme specific cho module Learning
struct LearningView: View {
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        NavigationView {
            VStack {
                LMSButton(title: "Start Learning", style: .primary)
            }
            .background(theme.background.primary)
        }
        .environment(\.appTheme, AppTheme.theme(for: .learning))
    }
}
```

## Component Theming Best Practices

### 1. LMSButton with Theme Support

```swift
// ✅ Button theming with theme type
LMSButton(title: "Primary", style: .primary)
LMSButton(title: "Secondary", style: .secondary)

// ✅ Custom button colors from theme
Button("Custom") {
    // action
}
.buttonStyle(ThemeButtonStyle(theme: theme, isPrimary: true))
```

### 2. LMSLabel/LMSTextField with Theme Colors

```swift
// ✅ Typography with theme colors
LMSLabel(text: "Title", style: .title)
    .foregroundColor(theme.text.primary)

Text("Body Text")
    .font(.body)
    .foregroundColor(theme.text.secondary)

Text("Error Message")
    .font(.caption)
    .foregroundColor(theme.text.error)

// ✅ Input fields
LMSTextField(placeholder: "Enter text", text: $inputText)
    .foregroundColor(theme.text.primary)
    .background(theme.background.secondary)
    .overlay(
        RoundedRectangle(cornerRadius: 8)
            .stroke(theme.border.regular, lineWidth: 1)
    )
```

### 3. Background and Border Colors

```swift
// ✅ Background theming
Color(theme.background.primary)
Color(theme.background.secondary)
Color(theme.background.overlay)

// ✅ Border theming
Divider()
    .background(theme.border.thin)

RoundedRectangle(cornerRadius: 8)
    .stroke(theme.border.regular, lineWidth: 1)
```

## Navigation Bar Theming

### 1. SwiftUI Navigation Styling

```swift
// ✅ Navigation bar theming
struct MyView: View {
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        NavigationView {
            contentView
                .navigationTitle("Title")
                .navigationBarTitleDisplayMode(.large)
        }
        .tint(theme.text.primary)
    }
}
    
    // Default implementation returns .chotot
    // Override for different themes:
    var ctNavigationBarData: CTNavigationBarData {
        return .pty  // hoặc .gds, .job
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyNavigationBarData()
    }
}
```

### 2. Custom Navigation Bar Styling

```swift
// ✅ Manual navigation bar theming
struct MyView: View {
    @Environment(\.appTheme) private var theme
    
    init() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(theme.background.brand)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(theme.text.primary)]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        // View content
    }
}
```

## Advanced Theme Patterns

### 1. Theme State Management with Combine

```swift
// ✅ Proper theme state management
import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .default
    
    func switchTheme(to themeType: ThemeType) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = AppTheme.theme(for: themeType)
        }
    }
}

struct MyView: View {
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        VStack {
            Text("Title")
                .foregroundColor(themeManager.currentTheme.text.primary)
        }
        .background(themeManager.currentTheme.background.primary)
    }
}
```

### 2. Theme-Aware Custom Components

```swift
// ✅ Custom component with theme support
struct ThemedCardView: View {
    @Environment(\.appTheme) private var theme
    
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(theme.text.primary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(theme.text.secondary)
        }
        .padding()
        .background(theme.background.secondary)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(theme.border.regular, lineWidth: 1)
        )
    }
}
```

### 3. Theme Context Passing

```swift
// ✅ Pass theme context to child components
struct ParentView: View {
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        VStack {
            ChildView()
                .environment(\.appTheme, theme)
        }
    }
}

struct ChildView: View {
    @Environment(\.appTheme) private var theme
    
    var body: some View {
        Text("Child View")
            .foregroundColor(theme.text.primary)
    }
}
```

## Common Anti-Patterns

### ❌ Avoid Hardcoded Colors

```swift
// ❌ BAD - Hardcoded colors
Text("Title")
    .foregroundColor(.black)
.background(Color.white)

Button("Action") { }
    .background(Color.blue)

// ✅ GOOD - Theme colors
@Environment(\.appTheme) private var theme

Text("Title")
    .foregroundColor(theme.text.primary)
.background(theme.background.primary)

LMSButton(title: "Action", style: .primary)
```

### ❌ Avoid Direct Theme Creation

```swift
// ❌ BAD - Creating theme instances directly
let theme = AppTheme() // Direct instantiation

// ✅ GOOD - Use Environment
@Environment(\.appTheme) private var theme
```

### ❌ Avoid Theme Switching Without Animation

```swift
// ❌ BAD - Abrupt theme change
func changeTheme(_ theme: AppTheme) {
    self.theme = theme
}

// ✅ GOOD - Animated theme change
func changeTheme(_ themeType: ThemeType) {
    withAnimation(.easeInOut(duration: 0.3)) {
        self.theme = AppTheme.theme(for: themeType)
    }
}
```

## Testing Theme Implementation

### 1. Theme Testing Pattern

```swift
// ✅ Unit testing with themes
import XCTest
import SwiftUI
@testable import report_lms

class MyViewTests: XCTestCase {
    
    func testThemeApplication() {
        let testTheme = AppTheme.theme(for: .assessment)
        let view = MyView()
            .environment(\.appTheme, testTheme)
        
        // Verify theme is applied correctly
        XCTAssertNotNil(view)
    }
    
    @MainActor
    func testThemeStateManagement() async {
        let themeManager = ThemeManager()
        
        themeManager.switchTheme(to: .assessment)
        
        // Wait for animation
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        XCTAssertEqual(themeManager.currentTheme.type, .assessment)
    }
}
```

## Performance Considerations

### 1. Theme Caching and Optimization

```swift
// ✅ Cache theme objects for performance
class ThemeCache {
    private static var cachedThemes: [ThemeType: AppTheme] = [:]
    
    static func theme(for type: ThemeType) -> AppTheme {
        if let cached = cachedThemes[type] {
            return cached
        }
        
        let theme = AppTheme.theme(for: type)
        cachedThemes[type] = theme
        return theme
    }
    
    static func clearCache() {
        cachedThemes.removeAll()
    }
}
```

## Summary

1. **Always use `@Environment(\.appTheme)`** for theme access in SwiftUI views
2. **Use `@AppStorage` or `@StateObject`** for dynamic theme switching
3. **Use proper theme types** (.default, .learning, .assessment) based on module
4. **Leverage LMS design system components** with theme support
5. **Animate theme transitions** with `withAnimation` for better UX
6. **Test theme implementations** thoroughly using SwiftUI testing
7. **Avoid hardcoded colors** - always use theme properties
8. **Cache themes** for performance optimization
9. **Use Environment for theme propagation** to child views
10. **Prefer native SwiftUI patterns** over UIKit approaches

Tuân thủ những best practices này sẽ đảm bảo theme system được sử dụng một cách consistent và maintainable trong toàn bộ report_lms iOS app.