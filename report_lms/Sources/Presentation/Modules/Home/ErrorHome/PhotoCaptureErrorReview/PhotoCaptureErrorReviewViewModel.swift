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
    @Published var images: [ImageSource] = []
    @Published var showCamera = false
    @Published var selectedSeverity: SeverityLevel = .low
    @Published var generalConditionEnabled = false
    @Published var selectedGeneralCondition: Int?
    @Published var selectedDefectType: DefectType?
    @Published var comments: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private let inspectionId: String
    private let errorRepository: ErrorRepositoryType
    private let logger = Logger(subsystem: "com.reportlms", category: "PhotoCaptureErrorReviewViewModel")

    // MARK: - Initialization
    init(inspectionId: String, errorRepository: ErrorRepositoryType? = nil) {
        self.inspectionId = inspectionId
        self.errorRepository = errorRepository ?? Container.shared.resolve(ErrorRepositoryType.self)!
    }

    // MARK: - Public Methods
    func addImages(_ newImages: [UIImage]) {
        images.append(contentsOf: newImages.map { .local(image: $0) })
    }

    func deleteImage(at index: Int) {
        guard index >= 0 && index < images.count else { return }
        images.remove(at: index)
    }

    func setInitialImages(_ initialImages: [ImageSource]) {
        images = initialImages
    }

    func saveReview() async -> SavedErrorItem? {
        isLoading = true
        defer { isLoading = false }

        guard !images.isEmpty else {
            errorMessage = "Vui lòng chụp ít nhất một ảnh"
            return nil
        }

        let item = buildSavedErrorItem()

        do {
            let saved = try await errorRepository.saveErrorItem(item, imageSources: images, for: inspectionId)
            return saved
        } catch {
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
            let saved = try await errorRepository.saveErrorItem(item, imageSources: images, for: inspectionId)
            logger.debug("[updateReview] ✅ saveErrorItem succeeded")
            return saved
        } catch {
            logger.error("[updateReview] ❌ saveErrorItem failed: \(error, privacy: .public)")
            errorMessage = "Không thể cập nhật đánh giá: \(error.localizedDescription)"
            return nil
        }
    }

    func deleteReview() {
        images.removeAll()
        selectedSeverity = .low
        generalConditionEnabled = false
        selectedGeneralCondition = nil
        selectedDefectType = nil
        comments = ""
    }

    // MARK: - Private Methods
    private func buildSavedErrorItem() -> SavedErrorItem {
        let existingURLs = images.compactMap { source -> String? in
            if case .remote(let url) = source { return url } else { return nil }
        }
        return SavedErrorItem(
            imageURLs: existingURLs,
            severity: selectedSeverity,
            generalCondition: generalConditionEnabled ? selectedGeneralCondition : nil,
            defectType: selectedDefectType,
            comments: comments
        )
    }
}

// MARK: - Inspection Review Data
struct InspectionReviewData {
    let images: [ImageSource]
    let severity: SeverityLevel
    let generalCondition: Int?
    let defectType: DefectType?
    let comments: String
}
