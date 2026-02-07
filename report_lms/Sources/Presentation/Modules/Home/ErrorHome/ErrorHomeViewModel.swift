//
//  ErrorHomeViewModel.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import SwiftUI

// MARK: - Error Item Model
struct ErrorItem: Identifiable {
    let id = UUID()
    let severity: SeverityLevel
    let defectType: DefectType
    let image: UIImage
    let affectedCount: Int
    let actualMeasurement: Double
    let maxAllowed: Double
    
    var headerText: String {
        "\(severity.displayName) - Số đo thực tế (\(Int(actualMeasurement))) - Tối đa cho phép (\(maxAllowed.isNaN ? "NaN" : String(Int(maxAllowed))))"
    }
    
    var defectDescription: String {
        defectType.displayName
    }
    
    var severityAndCountText: String {
        "\(severity.displayName) - \(affectedCount) bị ảnh hưởng"
    }
}

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

// MARK: - ErrorHomeViewModel

@MainActor
final class ErrorHomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var errors: [ErrorItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Initialization
    init() {
        // Don't call async methods in init - let the View handle this
    }

    // MARK: - Public Methods
    func loadErrors() async {
        isLoading = true
        defer { isLoading = false }

        // Simulate loading sample error data
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Sample data for demonstration
        errors = [
            ErrorItem(
                severity: .low,
                defectType: .crack,
                image: UIImage(systemName: "photo") ?? UIImage(),
                affectedCount: 1,
                actualMeasurement: 1.0,
                maxAllowed: Double.nan
            ),
            ErrorItem(
                severity: .medium,
                defectType: .stain,
                image: UIImage(systemName: "photo.fill") ?? UIImage(),
                affectedCount: 2,
                actualMeasurement: 2.0,
                maxAllowed: 1.5
            )
        ]
    }
}
