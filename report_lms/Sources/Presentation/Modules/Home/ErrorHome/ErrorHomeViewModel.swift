//
//  ErrorHomeViewModel.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import SwiftUI
import UIKit

// MARK: - ErrorHomeViewModel

@MainActor
final class ErrorHomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var errorInspections: [SavedErrorItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Properties
    let inspectionId: String

    // MARK: - Private Properties
    private let errorRepository: ErrorRepositoryType

    // MARK: - Initialization
    init(inspectionId: String, errorRepository: ErrorRepositoryType? = nil) {
        self.inspectionId = inspectionId
        self.errorRepository = errorRepository ?? Container.shared.resolve(ErrorRepositoryType.self)!
    }

    // MARK: - Public Methods
    func loadErrorInspections() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            errorInspections = try await errorRepository.fetchErrorItems(for: inspectionId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Thumbnail Cache
    @Published var thumbnailCache: [String: UIImage] = [:]

    /// Inserts a new item at the top (or replaces by id), caching the first UIImage for instant display.
    func upsertErrorItem(_ item: SavedErrorItem, thumbnails: [UIImage] = []) {
        if let first = thumbnails.first {
            thumbnailCache[item.id] = first
        }
        if let index = errorInspections.firstIndex(where: { $0.id == item.id }) {
            errorInspections[index] = item
        } else {
            errorInspections.insert(item, at: 0)
        }
    }
}
