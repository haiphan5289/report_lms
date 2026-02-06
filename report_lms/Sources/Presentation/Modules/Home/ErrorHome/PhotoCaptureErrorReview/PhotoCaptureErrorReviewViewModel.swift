//
//  PhotoCaptureReviewViewModel.swift
//  report_lms
//
//  Created by GitHub Copilot on 2/4/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI

// MARK: - Severity Level
enum SeverityLevel: String, CaseIterable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low: return "Nhẹ"
        case .medium: return "Trung bình"
        case .high: return "Nặng"
        }
    }
}

// MARK: - Defect Type
enum DefectType: String, CaseIterable {
    case crack
    case stain
    case hole
    case colorMismatch
    case sizeIssue

    var displayName: String {
        switch self {
        case .crack: return "Nứt"
        case .stain: return "Lốm đốm"
        case .hole: return "Lỗ"
        case .colorMismatch: return "Sai màu"
        case .sizeIssue: return "Sai kích thước"
        }
    }
}

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

    // MARK: - Initialization
    init() {}

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

    func saveReview() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Validate review data
            guard !images.isEmpty else {
                errorMessage = "Vui lòng chụp ít nhất một ảnh"
                return
            }

            // Placeholder: Implement actual save logic with repository/use case
            // try await saveReviewUseCase.execute(review: createReviewEntity())

            // Simulate async operation
            try await Task.sleep(nanoseconds: 500_000_000)

        } catch {
            errorMessage = "Không thể lưu đánh giá: \(error.localizedDescription)"
        }
    }

    func updateReview() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Placeholder: Implement actual update logic
            // try await updateReviewUseCase.execute(review: createReviewEntity())

            // Simulate async operation
            try await Task.sleep(nanoseconds: 500_000_000)

        } catch {
            errorMessage = "Không thể cập nhật đánh giá: \(error.localizedDescription)"
        }
    }

    func deleteReview() {
        // Reset all fields
        images.removeAll()
        selectedSeverity = .low
        generalConditionEnabled = false
        selectedGeneralCondition = nil
        selectedDefectType = nil
        comments = ""
    }

    // MARK: - Private Methods
    private func createReviewEntity() -> InspectionReviewData {
        InspectionReviewData(
            images: images,
            severity: selectedSeverity,
            generalCondition: generalConditionEnabled ? selectedGeneralCondition : nil,
            defectType: selectedDefectType,
            comments: comments
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
