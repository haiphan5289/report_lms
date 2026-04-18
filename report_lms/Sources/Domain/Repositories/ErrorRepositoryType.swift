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
    func saveErrorItem(_ item: SavedErrorItem, imageSources: [ImageSource], for inspectionId: String) async throws -> SavedErrorItem
}
