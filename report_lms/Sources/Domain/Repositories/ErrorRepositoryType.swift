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
    func fetchErrors(for inspectionId: String) async throws -> [Inspection]
    func fetchErrorItems(for inspectionId: String) async throws -> [Inspection]
    func saveError(_ inspection: Inspection, for inspectionId: String) async throws
    func saveErrorItem(_ inspection: Inspection, images: [UIImage], for inspectionId: String) async throws
}
