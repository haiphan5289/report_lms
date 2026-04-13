//
//  SearchableListViewModel.swift
//  report_lms
//
//  Created by Hai Phan on January 25, 2026.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

@MainActor
public final class SearchableListViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published public var searchText = ""
    @Published public var filteredItems: ListItemProtocol?
    @Published public var filteredSections: [ListItemProtocol] = []
    @Published public var selectedDataItems: Set<ListDataItem> = []

    // MARK: - Private Properties
    private var allItems: ListItemProtocol?
    private var allSections: [ListItemProtocol] = []
    private var customTitle: String?

    // MARK: - Computed Properties
    public var headerTitle: String {
        customTitle ?? filteredItems?.title ?? "Select Items"
    }

    public var isTwoLayerMode: Bool {
        allSections.count > 1
    }

    // MARK: - Initialization
    public init(items: ListItemProtocol? = nil) {
        self.allItems = items
        if let items = items {
            self.allSections = [items]
        }
        filterItems()
    }

    public init(sections: [ListItemProtocol], title: String? = nil) {
        self.allSections = sections
        self.customTitle = title
        filterItems()
    }

    // MARK: - Public Methods
    public func updateItems(_ items: ListItemProtocol?) {
        allItems = items
        filterItems()
    }

    public func toggleSelection(for dataItem: ListDataItem) {
        if selectedDataItems.contains(dataItem) {
            selectedDataItems.remove(dataItem)
        } else {
            selectedDataItems.insert(dataItem)
        }
    }

    public func isSelected(_ dataItem: ListDataItem) -> Bool {
        selectedDataItems.contains(dataItem)
    }

    public func clearSelection() {
        selectedDataItems.removeAll()
    }

    // MARK: - Private Methods
    private func filterItems() {
        if searchText.isEmpty {
            filteredItems = allItems
            filteredSections = allSections
        } else {
            // Single-item filtering (backward compat)
            if let item = allItems {
                if let title = item.title, title.localizedCaseInsensitiveContains(searchText) {
                    filteredItems = item
                } else {
                    let filteredDatas = item.datas.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                    filteredItems = filteredDatas.isEmpty ? nil : FilteredListItem(originalItem: item, filteredDatas: filteredDatas)
                }
            } else {
                filteredItems = nil
            }
            // Sections filtering
            filteredSections = allSections.compactMap { section in
                if let title = section.title, title.localizedCaseInsensitiveContains(searchText) {
                    return section
                }
                let filteredDatas = section.datas.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                guard !filteredDatas.isEmpty else { return nil }
                return FilteredListItem(originalItem: section, filteredDatas: filteredDatas)
            }
        }
    }

    // MARK: - Search Text Observer
    public func searchTextDidChange(_ newValue: String) {
        searchText = newValue
        filterItems()
    }
}

// MARK: - Filtered List Item
private struct FilteredListItem: ListItemProtocol {
    let title: String?
    let datas: [ListDataItem]

    init(originalItem: ListItemProtocol, filteredDatas: [ListDataItem]) {
        self.title = originalItem.title
        self.datas = filteredDatas
    }
}
