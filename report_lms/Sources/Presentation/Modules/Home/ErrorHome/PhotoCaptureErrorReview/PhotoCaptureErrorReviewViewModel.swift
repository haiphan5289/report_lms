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
    @Published var images: [UIImage] = []
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
        images.append(contentsOf: newImages)
    }

    func deleteImage(at index: Int) {
        guard index >= 0 && index < images.count else { return }
        images.remove(at: index)
    }

    func setInitialImages(_ initialImages: [UIImage]) {
        images = initialImages
    }

    func saveReview() async -> Inspection? {
        isLoading = true
        defer { isLoading = false }

        guard !images.isEmpty else {
            errorMessage = "Vui lòng chụp ít nhất một ảnh"
            return nil
        }

        let errorRecord = buildErrorInspection()

        do {
            try await errorRepository.saveError(errorRecord, for: inspectionId)
            return errorRecord
        } catch {
            errorMessage = "Không thể lưu đánh giá: \(error.localizedDescription)"
            return nil
        }
    }

    func updateReview() async -> Inspection? {
        isLoading = true
        defer { isLoading = false }

        let errorRecord = buildErrorInspection()
        logger.debug("[updateReview] START inspectionId=\(self.inspectionId, privacy: .public) imageCount=\(self.images.count, privacy: .public)")
        logger.debug("[updateReview] errorRecord.id=\(errorRecord.id, privacy: .public)")

        do {
            try await errorRepository.saveErrorItem(errorRecord, images: images, for: inspectionId)
            logger.debug("[updateReview] ✅ saveErrorItem succeeded")
            return errorRecord
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
    private func buildErrorInspection() -> Inspection {
        let defectName = selectedDefectType?.displayName ?? DefectType.su11.displayName
        let severityNote = selectedSeverity.displayName
        let note = comments.isEmpty ? defectName : comments

        return Inspection(
            productName: defectName,
            productCode: selectedSeverity.rawValue,
            orderCode: "",
            inspectionType: severityNote,
            quantity: "\(images.count) ảnh",
            factory: "",
            productionUnit: note,
            status: .error
        )
    }
}

// MARK: - Inspection Review Data
struct InspectionReviewData {
    let images: [UIImage]
    let severity: SeverityLevel
    let generalCondition: Int?
    let defectType: DefectType?
    let comments: String
}
