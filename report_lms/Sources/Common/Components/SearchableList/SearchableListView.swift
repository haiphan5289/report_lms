//
//  SearchableListView.swift
//  report_lms
//
//  Created by Hai Phan on January 25, 2026.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

public struct SearchableListView: View {
    // MARK: - Properties
    @StateObject private var viewModel: SearchableListViewModel
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss
    
    private let onItemSelected: (ListDataItem) -> Void
    
    // MARK: - Initialization
    public init(viewModel: SearchableListViewModel, onItemSelected: @escaping (ListDataItem) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onItemSelected = onItemSelected
    }
    
    // MARK: - Body
    public var body: some View {
        VStack(spacing: 0) {
            headerView
            searchBar
            listView
        }
        .onChange(of: searchText) { newValue in
            viewModel.searchTextDidChange(newValue)
        }
    }
    
    // MARK: - Private Views
    private var headerView: some View {
        HStack {
            LMSLabel(viewModel.filteredItems?.title ?? "Select Items", style: .headline)
            Spacer()
            LMSButton(
                "",
                icon: "xmark",
                variant: .iconOnly,
                size: .small,
                action: {
                    dismiss()
                }
            )
            .padding(.trailing, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
    }
    
    private var searchBar: some View {
        LMSTextField(
            "Search...",
            text: $searchText,
            icon: "magnifyingglass"
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    private var listView: some View {
        List {
            if let item = viewModel.filteredItems {
                ForEach(item.datas) { dataItem in
                    dataItemRow(dataItem)
                }
            }
        }
        .listStyle(.plain)
    }
    
    private func sectionHeader(for item: ListItemProtocol) -> some View {
        LMSLabel(item.title ?? "Items", style: .subheadline, color: .secondary)
    }
    
    private func dataItemRow(_ dataItem: ListDataItem) -> some View {
        HStack {
            LMSLabel(dataItem.name, style: .body)
            Spacer()
            if viewModel.isSelected(dataItem) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onItemSelected(dataItem)
            dismiss()
        }
    }
}

// MARK: - Preview
#Preview {
    let sampleItem = SampleListItem(title: "Fruits", datas: [
        ListDataItem(id: 1, name: "Apple"),
        ListDataItem(id: 2, name: "Banana"),
        ListDataItem(id: 3, name: "Orange")
    ])
    
    let viewModel = SearchableListViewModel(items: sampleItem)
    return SearchableListView(viewModel: viewModel) { selectedItem in
        // Handle selection
    }
}

// MARK: - Sample Implementation for Preview
private struct SampleListItem: ListItemProtocol {
    let title: String?
    let datas: [ListDataItem]
}
