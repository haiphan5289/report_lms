//
//  PhotoCaptureReviewViewModel.swift
//  report_lms
//
//  Created by GitHub Copilot on 2/4/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI
import OSLog

// MARK: - Photo Capture Review ViewModel
@MainActor
final class PhotoCaptureErrorReviewViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var images: [ImageWithNote] = []
    @Published var showCamera = false
    @Published var selectedSeverity: SeverityLevel = .low
    @Published var generalConditionEnabled = false
    @Published var selectedGeneralCondition: Int?
    @Published var selectedDefectType: DefectType?
    @Published var comments: String = ""
    @Published var isLoading = false
    @Published var isDownloading = false
    @Published var errorMessage: String?
    @Published var snackbarMessage: String?

    // MARK: - Private Properties
    let inspectionId: String  // Internal for debug access
    private let errorRepository: ErrorRepositoryType
    private let logger = Logger(subsystem: "com.reportlms", category: "PhotoCaptureErrorReviewViewModel")
    private var editingItemId: String?

    // MARK: - Computed Properties
    var isEditMode: Bool { editingItemId != nil }

    var localImages: [UIImage] {
        images.compactMap { if case .local(let img) = $0.source { return img } else { return nil } }
    }

    // MARK: - Initialization
    init(inspectionId: String, editingItem: SavedErrorItem? = nil, errorRepository: ErrorRepositoryType? = nil) {
        self.inspectionId = inspectionId
        guard let repo = errorRepository ?? Container.shared.resolve(ErrorRepositoryType.self) else {
            fatalError("ErrorRepositoryType not registered in DI container")
        }
        self.errorRepository = repo
        if let item = editingItem {
            editingItemId = item.id
            selectedSeverity = item.severity
            generalConditionEnabled = item.generalCondition != nil
            selectedGeneralCondition = item.generalCondition
            selectedDefectType = item.defectType
            comments = item.comments
        }
    }

    // MARK: - Image Management
    func addImages(_ newImages: [UIImage]) {
        images.append(contentsOf: newImages.map { ImageWithNote(source: .local(image: $0)) })
    }

    func deleteImage(at index: Int) {
        guard index >= 0 && index < images.count else { return }
        images.remove(at: index)
    }

    func setInitialImages(_ initialImages: [ImageWithNote]) {
        images = initialImages
    }

    func replaceImage(at index: Int, with image: UIImage) {
        guard index >= 0 && index < images.count else { return }
        images[index].source = .local(image: image)
    }

    func downloadImage(from url: String) async throws -> UIImage {
        guard let imageURL = URL(string: url) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: imageURL)
        guard let image = UIImage(data: data) else { throw URLError(.cannotDecodeContentData) }
        return image
    }

    // MARK: - Defect Type
    func defectTypeSearchableData() -> [ListItemProtocol] {
        let categories: [String] = ["PA", "SU", "AS", "FU", "SA", "FI", "CO", "FE", "TA"]
        return categories.compactMap { category -> ListItemProtocol? in
            let items = DefectType.allCases.filter { $0.category == category }
            guard !items.isEmpty else { return nil }
            let datas = items.map { ListDataItem(id: $0.rawValue.hashValue, name: $0.displayName) }
            return ErrorReviewListItem(title: items[0].categoryDisplayName, datas: datas)
        }
    }

    func selectDefectType(from item: ListDataItem) {
        let code = item.name.components(separatedBy: " - ").first ?? ""
        selectedDefectType = DefectType(rawValue: code)
    }

    // MARK: - Persistence
    func saveReview() async -> SavedErrorItem? {
        isLoading = true
        defer { isLoading = false }

        guard !images.isEmpty else {
            errorMessage = "Vui lòng chụp ít nhất một ảnh"
            return nil
        }

        let item = buildSavedErrorItem()
        logger.debug("[saveReview] START inspectionId=\(self.inspectionId, privacy: .public) imageCount=\(self.images.count, privacy: .public)")

        do {
            let saved = try await errorRepository.saveErrorItem(item, imageSources: images.map { $0.source }, for: inspectionId)
            logger.debug("[saveReview] ✅ saveErrorItem succeeded")
            return saved
        } catch {
            logger.error("[saveReview] ❌ saveErrorItem failed: \(error, privacy: .public)")
            errorMessage = "Không thể lưu đánh giá: \(error.localizedDescription)"
            return nil
        }
    }

    func updateReview() async -> SavedErrorItem? {
        isLoading = true
        defer { isLoading = false }

        let item = buildSavedErrorItem()
        logger.debug("[updateReview] START inspectionId=\(self.inspectionId, privacy: .public) imageCount=\(self.images.count, privacy: .public)")

        do {
            let saved = try await errorRepository.saveErrorItem(item, imageSources: images.map { $0.source }, for: inspectionId)
            logger.debug("[updateReview] ✅ saveErrorItem succeeded")
            return saved
        } catch {
            logger.error("[updateReview] ❌ saveErrorItem failed: \(error, privacy: .public)")
            errorMessage = "Không thể cập nhật đánh giá: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Private Methods
    private func buildSavedErrorItem() -> SavedErrorItem {
        let existingURLs = images.compactMap { item -> String? in
            if case .remote(let url) = item.source { return url } else { return nil }
        }
        return SavedErrorItem(
            id: editingItemId ?? UUID().uuidString,
            imageURLs: existingURLs,
            imageNotes: images.map { $0.note },
            severity: selectedSeverity,
            generalCondition: generalConditionEnabled ? selectedGeneralCondition : nil,
            defectType: selectedDefectType,
            comments: comments
        )
    }
}

// MARK: - List Item for Searchable Data
struct ErrorReviewListItem: ListItemProtocol {
    let title: String?
    let datas: [ListDataItem]
}
