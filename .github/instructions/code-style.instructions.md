---
applyTo: '**'
---
# Code Style Guide

## SwiftUI Principles

1. **Keep it Simple**: Use native SwiftUI patterns
2. **Modern Swift**: Use latest Swift features (async/await, @MainActor, etc.)
3. **SwiftUI Lifecycle**: Use SwiftUI's declarative lifecycle methods
4. **No External Dependencies**: Start with native SwiftUI/Swift before adding dependencies

## View Design

### Component Structure

```swift
struct ProfileView: View {
    // MARK: - Properties
    @StateObject private var viewModel: ProfileViewModel
    @State private var isEditing = false
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            contentView
                .navigationTitle("Profile")
                .toolbar { toolbarContent }
        }
    }
    
    // MARK: - Private Views
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeader
                profileDetails
                profileActions
            }
            .padding()
        }
    }
    
    private var profileHeader: some View {
        HStack {
            AsyncImage(url: viewModel.avatarURL) { image in
                image.resizable()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(viewModel.name)
                    .font(.title2)
                    .bold()
                Text(viewModel.email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("Edit") {
                isEditing.toggle()
            }
        }
    }
}
```

### View Composition

```swift
// ✅ Good - Extract complex views
struct ProductListView: View {
    let products: [Product]
    
    var body: some View {
        List(products) { product in
            ProductRow(product: product)
        }
    }
}

struct ProductRow: View {
    let product: Product
    
    var body: some View {
        HStack {
            ProductThumbnail(url: product.imageURL)
            ProductInfo(product: product)
            Spacer()
            ProductPrice(price: product.price)
        }
    }
}

// ❌ Bad - Nested complex views
struct ProductListView: View {
    let products: [Product]
    
    var body: some View {
        List(products) { product in
            HStack {
                AsyncImage(url: product.imageURL) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 50, height: 50)
                
                VStack(alignment: .leading) {
                    Text(product.name)
                    Text(product.description)
                }
                
                Spacer()
                
                Text("$\(product.price)")
            }
        }
    }
}
```

## Custom Modifiers

```swift
// Common/Modifiers/CardModifier.swift
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.white)
            .cornerRadius(8)
            .shadow(radius: 2)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }
}

// Usage
Text("Hello")
    .cardStyle()
```

## Reusable Components

```swift
// Common/Components/LoadingView.swift
struct LoadingView: View {
    var message: String = "Loading..."
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
            Text(message)
                .foregroundColor(.secondary)
        }
    }
}

// Common/Components/ErrorView.swift
struct ErrorView: View {
    let message: String
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text(message)
                .multilineTextAlignment(.center)
            
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

## Layout Best Practices

### Spacing

```swift
// ✅ Good - Consistent spacing
VStack(spacing: 16) {
    Text("Title")
    Text("Subtitle")
    Text("Content")
}

// ✅ Good - Semantic padding
.padding(.horizontal, 20)
.padding(.vertical, 16)
```

### Alignment

```swift
// ✅ Good - Explicit alignment
VStack(alignment: .leading, spacing: 12) {
    Text("Name")
        .font(.headline)
    Text("Description")
        .font(.subheadline)
}
```

### Frames

```swift
// ✅ Good - Specific dimensions
Image(systemName: "photo")
    .frame(width: 100, height: 100)

// ✅ Good - Flexible sizing
.frame(maxWidth: .infinity)
.frame(minHeight: 200)
```

## Color and Styling

```swift
// ✅ Good - Use semantic colors
.foregroundColor(.primary)
.background(Color.secondary.opacity(0.1))

// ✅ Good - Define custom colors in asset catalog
.foregroundColor(Color("AppPrimary"))

// ✅ Good - Support dark mode automatically
.background(Color(.systemBackground))
```

## Navigation

```swift
// ✅ Good - NavigationStack (iOS 16+)
NavigationStack {
    List(items) { item in
        NavigationLink(value: item) {
            ItemRow(item: item)
        }
    }
    .navigationDestination(for: Item.self) { item in
        ItemDetailView(item: item)
    }
}

// ✅ Good - Sheet presentation
.sheet(isPresented: $showingDetail) {
    DetailView(item: selectedItem)
}
```

## Animations

```swift
// ✅ Good - Simple animations
.animation(.spring(), value: isExpanded)

// ✅ Good - Custom animations
withAnimation(.easeInOut(duration: 0.3)) {
    showContent.toggle()
}
```

## Performance

```swift
// ✅ Good - Lazy loading
ScrollView {
    LazyVStack {
        ForEach(items) { item in
            ItemView(item: item)
        }
    }
}

// ✅ Good - Equatable for complex views
struct ProductCard: View, Equatable {
    let product: Product
    
    static func == (lhs: ProductCard, rhs: ProductCard) -> Bool {
        lhs.product.id == rhs.product.id
    }
}
```

## Preview Providers

```swift
// ✅ Good - Multiple preview configurations
#Preview("Default") {
    UserProfileView(viewModel: .preview)
}

#Preview("Loading") {
    UserProfileView(viewModel: .previewLoading)
}

#Preview("Error") {
    UserProfileView(viewModel: .previewError)
}

#Preview("Dark Mode") {
    UserProfileView(viewModel: .preview)
        .preferredColorScheme(.dark)
}
```

## Common Anti-Patterns to Avoid

```swift
// ❌ Bad - Complex logic in views
var body: some View {
    VStack {
        if items.filter { $0.isActive }.count > 5 {
            Text("Many items")
        }
    }
}

// ✅ Good - Move logic to ViewModel
var body: some View {
    VStack {
        if viewModel.hasManyActiveItems {
            Text("Many items")
        }
    }
}

// ❌ Bad - Direct API calls in views
.task {
    let url = URL(string: "https://api.example.com")!
    let (data, _) = try! await URLSession.shared.data(from: url)
}

// ✅ Good - Use ViewModels and Use Cases
.task {
    await viewModel.loadData()
}
```
