//
//  ListItemProtocol.swift
//  report_lms
//
//  Created by Hai Phan on January 25, 2026.
//  Copyright © 2026 report_lms. All rights reserved.
//

import Foundation

/// Protocol defining an item that can be displayed in a searchable list
public protocol ListItemProtocol {
    /// Optional title for the item
    var title: String? { get }
    
    /// Array of data items containing name and id
    var datas: [ListDataItem] { get }
}

/// Struct representing a data item with name and id
public struct ListDataItem: Identifiable, Equatable, Hashable {
    public let id: Int
    public let name: String
    
    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: ListDataItem, rhs: ListDataItem) -> Bool {
        lhs.id == rhs.id
    }
}