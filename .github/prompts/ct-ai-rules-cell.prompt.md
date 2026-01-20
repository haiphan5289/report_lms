````prompt
---
description: "Generate basic SwiftUI row/item view component with LMS design"
mode: "agent"
---

# iOS Basic Row/Item Component Generator

Generate basic SwiftUI row or item view component using native SwiftUI or LMS custom components.

## Instructions

Reference our iOS development guidelines:

-   **Primary**: [iOS Guidelines](../instructions/ios-general-instructions.instructions.md)
-   **Fallback**: [AI Agent Context](../../AGENTS.md) (if primary unavailable)

Generate basic row/item component with:

-   SwiftUI View for list rows or grid items
-   ViewModel struct for data binding
-   Native SwiftUI components or LMS custom components
-   Proper spacing and layout
-   TODO comments for implementation

## Row Component Template (List)

```swift
import SwiftUI

struct [Name]Row: View {
    
    // MARK: - Properties
    
    let viewModel: [Name]RowViewModel
    
    enum Config {
        // TODO: Add configuration constants
        // static let cornerRadius: CGFloat = 8
        // static let padding: CGFloat = 16
        // static let imageSize: CGFloat = 60
        // static let spacing: CGFloat = 12
    }
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: Config.spacing) {
            // TODO: Add row content using native SwiftUI or LMS components
            // thumbnailView
            // contentView
            // Spacer()
            // accessoryView
        }
        .padding(Config.padding)
        .background(Color(.systemBackground))
        .cornerRadius(Config.cornerRadius)
    }
    
    // MARK: - Private Views
    
    // TODO: Extract complex views
    // private var thumbnailView: some View {
    //     AsyncImage(url: viewModel.imageURL) { image in
    //         image.resizable()
    //             .scaledToFill()
    //     } placeholder: {
    //         ProgressView()
    //     }
    //     .frame(width: Config.imageSize, height: Config.imageSize)
    //     .clipShape(RoundedRectangle(cornerRadius: 8))
    // }
    //
    // private var contentView: some View {
    //     VStack(alignment: .leading, spacing: 4) {
    //         Text(viewModel.title)
    //             .font(.headline)
    //         Text(viewModel.subtitle)
    //             .font(.subheadline)
    //             .foregroundColor(.secondary)
    //     }
    // }
}

// MARK: - Preview

#Preview("Default") {
    [Name]Row(viewModel: [Name]RowViewModel.preview)
}

#Preview("List") {
    List {
        [Name]Row(viewModel: [Name]RowViewModel.preview)
        [Name]Row(viewModel: [Name]RowViewModel.preview)
    }
}
```

## Item Component Template (Grid)

```swift
import SwiftUI

struct [Name]Item: View {
    
    // MARK: - Properties
    
    let viewModel: [Name]ItemViewModel
    
    enum Config {
        // TODO: Add configuration constants
        // static let cornerRadius: CGFloat = 12
        // static let padding: CGFloat = 12
        // static let imageHeight: CGFloat = 150
        // static let spacing: CGFloat = 8
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: Config.spacing) {
            // TODO: Add item content
            // imageView
            // titleView
            // detailsView
        }
        .padding(Config.padding)
        .background(Color(.systemBackground))
        .cornerRadius(Config.cornerRadius)
        .shadow(radius: 2)
    }
    
    // MARK: - Private Views
    
    // TODO: Extract complex views
    // private var imageView: some View {
    //     AsyncImage(url: viewModel.imageURL) { image in
    //         image.resizable()
    //             .scaledToFill()
    //     } placeholder: {
    //         Color.gray.opacity(0.2)
    //     }
    //     .frame(height: Config.imageHeight)
    //     .clipShape(RoundedRectangle(cornerRadius: 8))
    // }
    //
    // private var titleView: some View {
    //     Text(viewModel.title)
    //         .font(.headline)
    //         .lineLimit(2)
    // }
}

// MARK: - Preview

#Preview("Single Item") {
    [Name]Item(viewModel: [Name]ItemViewModel.preview)
        .frame(width: 200)
}

#Preview("Grid") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
            ForEach(0..<6) { _ in
                [Name]Item(viewModel: [Name]ItemViewModel.preview)
            }
        }
        .padding()
    }
}
```

## ViewModel Template

```swift
import Foundation

struct [Name]RowViewModel: Identifiable, Equatable {
    
    // MARK: - Properties
    
    let id: String
    // TODO: Add properties for row data
    // let title: String
    // let subtitle: String?
    // let imageURL: URL?
    // let isEnabled: Bool
    
    // MARK: - Computed Properties
    
    // TODO: Add computed properties for UI binding
    // var displayTitle: String {
    //     title.isEmpty ? "No Title" : title
    // }
    //
    // var displaySubtitle: String {
    //     subtitle ?? "No description"
    // }
}

// MARK: - Preview Support

extension [Name]RowViewModel {
    static var preview: [Name]RowViewModel {
        [Name]RowViewModel(
            id: "preview-1"
            // TODO: Add preview values
            // title: "Sample Title",
            // subtitle: "Sample subtitle text",
            // imageURL: URL(string: "https://via.placeholder.com/150")
        )
    }
    
    static var previews: [[Name]RowViewModel] {
        [
            preview,
            [Name]RowViewModel(id: "preview-2"),
            [Name]RowViewModel(id: "preview-3")
        ]
    }
}
```

## Using LMS Custom Components

```swift
import SwiftUI

struct [Name]Row: View {
    
    let viewModel: [Name]RowViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Using LMS custom components
            // LMSLabel(text: viewModel.title, style: .headline)
            // LMSButton(title: "Action", style: .primary) {
            //     // Action
            // }
            
            // Or native SwiftUI
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.title)
                    .font(.headline)
                Text(viewModel.subtitle ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
```

## Template Variables

-   `${input:componentName}`: Component name (e.g., "UserProfile", "CourseCard")
-   `${input:componentType}`: "Row" or "Item"
-   `${input:feature}`: Feature module (e.g., "report_lms")
-   `${input:dataModel}`: The data model type (e.g., "User", "Course", "Report")

## Usage Examples

-   `/ios-component componentName:UserProfile componentType:Row feature:report_lms dataModel:User`
-   `/ios-component componentName:CourseCard componentType:Item feature:report_lms dataModel:Course`

## Output

Generate basic component with:

1. SwiftUI View with proper structure
2. Config enum for constants
3. ViewModel struct with computed properties
4. Preview providers for development
5. LMS custom components or native SwiftUI
6. TODO comments for implementation
7. Proper spacing and layout patterns

Keep implementation minimal with TODO guidance for customization.

````