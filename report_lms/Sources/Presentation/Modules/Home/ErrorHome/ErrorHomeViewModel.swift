//
//  ErrorHomeViewModel.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import SwiftUI
import UIKit
import OSLog

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
    private let logger = Logger(subsystem: "com.reportlms", category: "ErrorHomeViewModel")

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
            await loadLocalThumbnails()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// For items with no remote imageURLs, load first image from LocalImageStore into thumbnailCache.
    private func loadLocalThumbnails() async {
        let pendingItems = errorInspections.filter { $0.imageURLs.isEmpty && thumbnailCache[$0.id] == nil }
        guard !pendingItems.isEmpty else { return }
        for item in pendingItems {
            let imgs = await LocalImageStore.shared.load(for: item.id)
            if let first = imgs.first {
                thumbnailCache[item.id] = first
            }
        }
    }

    // MARK: - Thumbnail Cache
    @Published var thumbnailCache: [String: UIImage] = [:]
    @Published var scrollToTopTrigger: Int = 0

    func removeErrorItem(id: String) {
        errorInspections.removeAll { $0.id == id }
        thumbnailCache.removeValue(forKey: id)
    }

    func deleteErrorItem(_ item: SavedErrorItem) {
        removeErrorItem(id: item.id)
        Task {
            do {
                try await errorRepository.deleteErrorItem(item, for: inspectionId)
                logger.debug("[deleteErrorItem] ✅ \(item.id, privacy: .public)")
            } catch {
                logger.error("[deleteErrorItem] ❌ re-fetch \(item.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
                await loadErrorInspections()
            }
        }
    }

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
