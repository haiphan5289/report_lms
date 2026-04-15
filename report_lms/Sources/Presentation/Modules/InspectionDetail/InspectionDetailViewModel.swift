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
    @Published var snackbarMessage: String?
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
    let inspectionId: String
    private let inspectionNumber: String
    private weak var homeViewModel: LMSHomeViewModel?
    private let storageService: InspectionStorageServiceType
    private var hasLoadedOnce = false

    // MARK: - Initialization
    init(inspectionId: String, inspectionNumber: String, homeViewModel: LMSHomeViewModel? = nil) {
        self.inspectionId = inspectionId
        self.inspectionNumber = inspectionNumber
        self.homeViewModel = homeViewModel
        self.storageService = Container.shared.resolve(InspectionStorageServiceType.self)!
    }

    // MARK: - Public Methods

    func loadInspectionDetail() async {
        guard !hasLoadedOnce else { return }
        hasLoadedOnce = true

        isLoading = true
        errorMessage = nil

        if let loaded = storageService.getInspection(by: inspectionId) {
            inspection = loaded
        } else {
            inspection = Inspection.mock(
                inspectionId: inspectionId,
                inspectionNumber: inspectionNumber
            )
        }

        // Dismiss overlay as soon as inspection data is ready — photos load lazily in the UI
        isLoading = false
        contentViewModel.autoExpandFirstSection()

        // Populate capturedPhotos with remote URLs immediately — no network download needed.
        // Views use AsyncImage(url:) for lazy, on-demand loading.
        if let loaded = inspection {
            restoreCapturedPhotos(from: loaded)
        }
    }

    /// Wraps Firebase Storage URLs into InspectionImage.remoteURL entries synchronously.
    /// No network call — AsyncImage handles the actual download per-view, on demand.
    private func restoreCapturedPhotos(from inspection: Inspection) {
        for section in inspection.sections {
            for field in section.fields where !field.imageURLs.isEmpty && capturedPhotos[field.id] == nil {
                capturedPhotos[field.id] = field.imageURLs.compactMap { urlString in
                    guard let url = URL(string: urlString) else { return nil }
                    return InspectionImage(remoteURL: url)
                }
            }
        }
    }

    func refreshInspection() {
        if let updated = storageService.getInspection(by: inspectionId) {
            inspection = updated
        }
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
        capturedPhotos[validation.id] = validation.images
        showValidation = false
        selectedValidationField = nil
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
            case .inspectionDetail: return "inspection.tab.inspection"
            case .error: return "inspection.tab.error"
            case .orderInformation: return "inspection.tab.info"
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
