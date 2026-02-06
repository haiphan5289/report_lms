//
//  InspectionDetailViewModel.swift
//  report_lms
//
//  Created by GitHub Copilot on 1/2/26.
//

import Foundation
import SwiftUI

@MainActor
final class InspectionDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var inspectionDetail: InspectionDetail?
    @Published var expandedSections: Set<String> = []
    @Published var capturedPhotos: [String: [UIImage]] = [:] // fieldId: [images]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showCamera = false
    @Published var selectedFieldId: String?
    @Published var isSubmitted = false

    // MARK: - Private Properties
    private let inspectionId: String
    private let inspectionNumber: String

    // MARK: - Initialization
    init(inspectionId: String, inspectionNumber: String) {
        self.inspectionId = inspectionId
        self.inspectionNumber = inspectionNumber
    }

    // MARK: - Public Methods

    func loadInspectionDetail() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // For now, use mock data
        inspectionDetail = InspectionDetail.mock(
            inspectionId: inspectionId,
            inspectionNumber: inspectionNumber
        )

        // Auto-expand first section
        if let firstSection = inspectionDetail?.sections.first {
            expandedSections.insert(firstSection.id)
        }
    }

    func toggleSection(_ sectionId: String) {
        if expandedSections.contains(sectionId) {
            expandedSections.remove(sectionId)
        } else {
            expandedSections.insert(sectionId)
        }
    }

    func isExpanded(_ sectionId: String) -> Bool {
        expandedSections.contains(sectionId)
    }

    func hasPhoto(for fieldId: String) -> Bool {
        !(capturedPhotos[fieldId]?.isEmpty ?? true)
    }

    func getImages(for fieldId: String) -> [UIImage] {
        return capturedPhotos[fieldId] ?? []
    }

    func openPhotoPicker(for fieldId: String) {
        selectedFieldId = fieldId
        showCamera = true
    }

    func savePhoto(_ image: UIImage, for fieldId: String) {
        if capturedPhotos[fieldId] == nil {
            capturedPhotos[fieldId] = []
        }
        capturedPhotos[fieldId]?.append(image)
    }

    func handlePhotoSelection(_ images: [UIImage]) {
        guard let fieldId = selectedFieldId else { return }
        for image in images {
            savePhoto(image, for: fieldId)
        }
        selectedFieldId = nil
    }

    func submitInspection() async {
        // Implement submission logic
        // Validate required fields
        // Upload photos
        // Submit form data
        isLoading = true
        defer { isLoading = false }

        do {
            // Add actual submission implementation
            try await Task.sleep(nanoseconds: 1_000_000_000) // Simulate network call
            isSubmitted = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview Helpers
extension InspectionDetailViewModel {
    static func preview() -> InspectionDetailViewModel {
        let viewModel = InspectionDetailViewModel(
            inspectionId: "1",
            inspectionNumber: "001"
        )
        Task { @MainActor in
            await viewModel.loadInspectionDetail()
        }
        return viewModel
    }
}
