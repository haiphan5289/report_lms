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
    case low = "low"
    case medium = "medium"
    case high = "high"

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
    case crack = "crack"
    case stain = "stain"
    case hole = "hole"
    case colorMismatch = "colorMismatch"
    case sizeIssue = "sizeIssue"

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
}