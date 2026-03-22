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
    @Published var inspection: Inspection?
    @Published var capturedPhotos: [String: [InspectionImage]] = [:] // fieldId: [images]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showCamera = false
    @Published var selectedFieldId: String?
    @Published var isSubmitted = false
    @Published var showValidation = false
    @Published var selectedValidationField: (id: String, label: String)?
    @Published var selectedTab: Tab = .inspectionDetail

    // MARK: - Child ViewModels
    private(set) lazy var contentViewModel: InspectionDetailContentViewModel = {
        InspectionDetailContentViewModel(
            parentViewModel: self,
            onTextTap: { [weak self] fieldId in
                self?.openValidationView(for: fieldId)
            },
            onCameraTap: { [weak self] fieldId in
                self?.openCamera(for: fieldId)
            }
        )
    }()

    // MARK: - Private Properties
    private let inspectionId: String
    private let inspectionNumber: String
    private weak var homeViewModel: LMSHomeViewModel?

    // MARK: - Initialization
    init(inspectionId: String, inspectionNumber: String, homeViewModel: LMSHomeViewModel? = nil) {
        self.inspectionId = inspectionId
        self.inspectionNumber = inspectionNumber
        self.homeViewModel = homeViewModel
    }

    // MARK: - Public Methods

    func loadInspectionDetail() async {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        // Simulate network delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // For now, use mock data
        inspection = Inspection.mock(
            inspectionId: inspectionId,
            inspectionNumber: inspectionNumber
        )

        // Auto-expand first section in content view
        contentViewModel.autoExpandFirstSection()
    }

    func getImages(for fieldId: String) -> [InspectionImage] {
        return capturedPhotos[fieldId] ?? []
    }

    private func hasPhoto(for fieldId: String) -> Bool {
        !(capturedPhotos[fieldId]?.isEmpty ?? true)
    }

    func openValidationView(for fieldId: String) {
        let fieldLabel = findFieldLabel(for: fieldId)
        selectedValidationField = (id: fieldId, label: fieldLabel)
        showValidation = true
    }
    
    func openCamera(for fieldId: String) {
        selectedFieldId = fieldId
        showCamera = true
    }
    
    func handleValidationSave(_ validation: FieldValidation) {
        // Update captured photos with validated images
        capturedPhotos[validation.id] = validation.images
        
        // Close validation view first
        showValidation = false
        selectedValidationField = nil
        
        // Switch to order information tab
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            selectedTab = .orderInformation
        }
    }
    
    private func findFieldLabel(for fieldId: String) -> String {
        guard let detail = inspection else { return "Field" }
        
        for section in detail.sections {
            if let field = section.fields.first(where: { $0.id == fieldId }) {
                return field.label
            }
        }
        
        return "Field"
    }

    func savePhoto(_ image: UIImage, for fieldId: String) {
        if capturedPhotos[fieldId] == nil {
            capturedPhotos[fieldId] = []
        }
        capturedPhotos[fieldId]?.append(InspectionImage(image: image))
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

// MARK: - Tab Enum
extension InspectionDetailViewModel {
    enum Tab: Int, CaseIterable {
        case inspectionDetail, error, orderInformation

        var title: String {
            switch self {
            case .inspectionDetail: return "Kiểm tra"
            case .error: return "Lỗi"
            case .orderInformation: return "Thông tin"
            }
        }

        var icon: String {
            switch self {
            case .inspectionDetail: return "doc.text.magnifyingglass"
            case .error: return "exclamationmark.triangle"
            case .orderInformation: return "info.circle"
            }
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
    
    static func previewWithData() -> InspectionDetailViewModel {
        let viewModel = InspectionDetailViewModel(
            inspectionId: "1",
            inspectionNumber: "001"
        )
        // Set mock data directly for immediate preview rendering
        viewModel.inspection = Inspection.mock(
            inspectionId: "1",
            inspectionNumber: "001"
        )
        viewModel.contentViewModel.autoExpandFirstSection()
        return viewModel
    }
    
    static func previewWithError() -> InspectionDetailViewModel {
        let viewModel = InspectionDetailViewModel(
            inspectionId: "1",
            inspectionNumber: "001"
        )
        viewModel.errorMessage = "Không thể tải dữ liệu. Vui lòng kiểm tra kết nối mạng."
        return viewModel
    }
}
