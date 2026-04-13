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
    @Environment(\..dismiss) private var dismiss

    private let onItemSelected: (ListDataItem) -> Void

    // MARK: - Initialization
    public init(viewModel: SearchableListViewModel, onItemSelected: @escaping (ListDataItem) -> Void) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onItemSelected = onItemSelected
    }

    // MARK: - Body
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                listView
            }
            .navigationTitle(viewModel.headerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
            }
            .onChange(of: searchText) { _, newValue in
                viewModel.searchTextDidChange(newValue)
            }
        }
    }

    // MARK: - Private Views
    private var searchBar: some View {
        LMSTextField(
            "Nhập để tìm kiếm",
            text: $searchText,
            icon: "magnifyingglass"
        )
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var listView: some View {
        List {
            listContent
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var listContent: some View {
        if viewModel.isTwoLayerMode && searchText.isEmpty {
            // Screen 1: category rows → push to Screen 2
            ForEach(Array(viewModel.filteredSections.enumerated()), id: \.offset) { _, section in
                NavigationLink {
                    SearchableItemListView(
                        section: section,
                        isSelected: { viewModel.isSelected($0) },
                        onItemSelected: { item in
                            onItemSelected(item)
                            dismiss()
                        }
                    )
                } label: {
                    LMSLabel(section.title ?? "", style: .body)
                }
            }
        } else {
            // Flat search results OR single-section mode
            ForEach(Array(viewModel.filteredSections.enumerated()), id: \.offset) { _, section in
                Section {
                    ForEach(section.datas) { dataItem in
                        dataItemRow(dataItem)
                    }
                } header: {
                    if let title = section.title, viewModel.filteredSections.count > 1 {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }
                }
            }
        }
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

// MARK: - Screen 2: Items in selected category
struct SearchableItemListView: View {
    // MARK: - Properties
    let section: ListItemProtocol
    let isSelected: (ListDataItem) -> Bool
    let onItemSelected: (ListDataItem) -> Void

    @State private var searchText = ""

    // MARK: - Computed
    private var filteredItems: [ListDataItem] {
        searchText.isEmpty
            ? section.datas
            : section.datas.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            searchBar
            List {
                ForEach(filteredItems) { dataItem in
                    dataItemRow(dataItem)
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(section.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Private Views
    private var searchBar: some View {
        LMSTextField(
            "Nhập để tìm kiếm",
            text: $searchText,
            icon: "magnifyingglass"
        )
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func dataItemRow(_ dataItem: ListDataItem) -> some View {
        HStack {
            LMSLabel(dataItem.name, style: .body)
            Spacer()
            if isSelected(dataItem) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onItemSelected(dataItem)
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
    return SearchableListView(viewModel: viewModel) { _ in
        // Handle selection
    }
}

// MARK: - Sample Implementation for Preview
private struct SampleListItem: ListItemProtocol {
    let title: String?
    let datas: [ListDataItem]
}
