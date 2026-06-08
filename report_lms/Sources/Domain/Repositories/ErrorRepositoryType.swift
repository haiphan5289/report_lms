//
//  ErrorRepositoryType.swift
//  report_lms
//
//  Created by GitHub Copilot on 12/4/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import Foundation
import UIKit

// MARK: - ErrorRepositoryType

protocol ErrorRepositoryType {
    func fetchErrorItems(for inspectionId: String) async throws -> [SavedErrorItem]
    func saveError(_ item: SavedErrorItem, for inspectionId: String) async throws
    func saveErrorItem(
        _ item: SavedErrorItem,
        imageSources: [ImageSource],
        for inspectionId: String,
        onImageProgress: (@Sendable (Int, Double) -> Void)?,
        onImageDone: (@Sendable (Int) -> Void)?,
        onImageFail: (@Sendable (Int) -> Void)?
    ) async throws -> SavedErrorItem
    func deleteErrorItem(_ item: SavedErrorItem, for inspectionId: String) async throws
}

extension ErrorRepositoryType {
    func saveErrorItem(_ item: SavedErrorItem, imageSources: [ImageSource], for inspectionId: String) async throws -> SavedErrorItem {
        try await saveErrorItem(item, imageSources: imageSources, for: inspectionId, onImageProgress: nil, onImageDone: nil, onImageFail: nil)
    }
}
