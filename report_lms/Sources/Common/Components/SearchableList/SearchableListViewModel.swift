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
    @Published public var selectedDataItems: Set<ListDataItem> = []
    
    // MARK: - Private Properties
    private var allItems: ListItemProtocol?
    
    // MARK: - Initialization
    public init(items: ListItemProtocol? = nil) {
        self.allItems = items
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
        } else {
            if let item = allItems {
                // Search in title
                if let title = item.title, title.localizedCaseInsensitiveContains(searchText) {
                    filteredItems = item
                    return
                }
                // Search in data item names
                let filteredDatas = item.datas.filter { dataItem in
                    dataItem.name.localizedCaseInsensitiveContains(searchText)
                }
                if !filteredDatas.isEmpty {
                    // Create a new item with filtered datas
                    filteredItems = FilteredListItem(originalItem: item, filteredDatas: filteredDatas)
                } else {
                    filteredItems = nil
                }
            } else {
                filteredItems = nil
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