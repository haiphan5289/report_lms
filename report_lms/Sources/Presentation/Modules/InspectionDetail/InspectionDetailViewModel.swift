//
//  InspectionDetailViewModel.swift
//  report_lms
//
//  Created by GitHub Copilot on 1/2/26.
//

import Foundation
import SwiftUI

struct ValidationFieldSelection: Hashable {
    let id: String
    let label: String
}

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
    @Published var selectedValidationField: ValidationFieldSelection?
    @Published var selectedTab: Tab = .inspectionDetail

    // MARK: - Upload Tracking
    @Published var activeUploadCount: Int = 0
    @Published var showUploadStatusSheet: Bool = false
    @Published var uploadSessions: [FieldUploadSession] = []
    var pendingEmailSend: Bool = false

    /// Total number of images still in-flight (pending or uploading) across all active sessions.
    var totalUploadingImageCount: Int {
        uploadSessions.reduce(0) { count, session in
            count + session.items.filter {
                if case .done = $0.status { return false }
                if case .failed = $0.status { return false }
                return true
            }.count
        }
    }
    @Published var selectedErrorItem: SavedErrorItem? = nil {
        didSet {
            print("🔍 [InspectionDetailVM] selectedErrorItem changed:")
            print("   - Old: \(oldValue?.id ?? "nil")")
            print("   - New: \(selectedErrorItem?.id ?? "nil")")
        }
    }

    // MARK: - Child ViewModels
    private(set) lazy var errorHomeViewModel: ErrorHomeViewModel = {
        ErrorHomeViewModel(inspectionId: inspectionId)
    }()

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
    init(
        inspectionId: String,
        inspectionNumber: String,
        homeViewModel: LMSHomeViewModel? = nil,
        storageService: InspectionStorageServiceType? = nil
    ) {
        self.inspectionId = inspectionId
        self.inspectionNumber = inspectionNumber
        self.homeViewModel = homeViewModel
        guard let service = storageService ?? Container.shared.resolve(InspectionStorageServiceType.self) else {
            fatalError("InspectionStorageServiceType must be registered in DI container")
        }
        self.storageService = service
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

        // Retry any uploads that were interrupted (e.g. app killed before upload completed).
        // Runs in background Tasks — does not block the UI.
        retryAllPendingUploads()
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

    /// On app reopen, retries uploads for every field that has locally-cached images not yet in Firebase.
    /// Creates a short-lived InspectionValidationViewModel per field so all upload/callback logic is reused.
    private func retryAllPendingUploads() {
        guard let inspectionId = inspection?.id else { return }
        let pendingFields = PendingUploadStore.shared.getAllPendingFields(for: inspectionId)
        guard !pendingFields.isEmpty else { return }

        for (fieldId, _) in pendingFields {
            let fieldLabel = findFieldLabel(for: fieldId)
            let callbacks = makeUploadCallbacks(for: fieldId)
            let existingImages = capturedPhotos[fieldId] ?? []
            let sid = inspectionId

            Task { @MainActor [weak self] in
                guard let self else { return }
                let vm = InspectionValidationViewModel(
                    fieldId: fieldId,
                    fieldLabel: fieldLabel,
                    initialImages: existingImages,
                    inspectionId: sid,
                    onSilentSave: { [weak self] validation in
                        self?.handleValidationUpdate(validation)
                    },
                    onTaskCompleted: { [weak self] in
                        self?.notifyUploadCompleted()
                    },
                    onImageProgress: callbacks.onProgress,
                    onImageDone: callbacks.onDone,
                    onImageFail: callbacks.onFail
                )
                await vm.loadPendingCaptures()
            }
        }
    }

    func refreshInspection() {
        if let updated = storageService.getInspection(by: inspectionId) {
            inspection = updated
        }
    }

    // MARK: - Upload Tracking

    func notifyUploadStarted() {
        activeUploadCount += 1
    }

    func notifyUploadCompleted() {
        activeUploadCount = max(0, activeUploadCount - 1)
        if activeUploadCount == 0 {
            uploadSessions.removeAll { $0.isComplete }
        }
    }

    // MARK: - Per-Image Progress Tracking

    func startUploadSession(fieldId: String, images: [InspectionImage]) {
        let localImages = images.filter { !$0.isRemote }
        guard !localImages.isEmpty else { return }
        let label = findFieldLabel(for: fieldId)
        let session = FieldUploadSession(
            id: fieldId,
            fieldLabel: label,
            items: localImages.enumerated().map { idx, img in
                ImageUploadItem(id: "\(fieldId)-\(idx)", imageIndex: idx, thumbnail: img.image, status: .pending)
            }
        )
        uploadSessions.removeAll { $0.id == fieldId }
        uploadSessions.append(session)
        notifyUploadStarted()
    }

    func updateImageProgress(fieldId: String, imageIndex: Int, progress: Double) {
        guard let si = uploadSessions.firstIndex(where: { $0.id == fieldId }),
              uploadSessions[si].items.indices.contains(imageIndex) else { return }
        uploadSessions[si].items[imageIndex].status = .uploading(progress: progress)
    }

    func markImageDone(fieldId: String, imageIndex: Int) {
        guard let si = uploadSessions.firstIndex(where: { $0.id == fieldId }),
              uploadSessions[si].items.indices.contains(imageIndex) else { return }
        uploadSessions[si].items[imageIndex].status = .done
    }

    func markImageFailed(fieldId: String, imageIndex: Int) {
        guard let si = uploadSessions.firstIndex(where: { $0.id == fieldId }),
              uploadSessions[si].items.indices.contains(imageIndex) else { return }
        uploadSessions[si].items[imageIndex].status = .failed
    }

    /// Returns @Sendable callbacks for a field's upload session to be passed into InspectionValidationViewModel.
    func makeUploadCallbacks(for fieldId: String) -> (
        onProgress: @Sendable (Int, Double) -> Void,
        onDone: @Sendable (Int) -> Void,
        onFail: @Sendable (Int) -> Void
    ) {
        return (
            onProgress: { [weak self] index, progress in
                Task { @MainActor [weak self] in
                    self?.updateImageProgress(fieldId: fieldId, imageIndex: index, progress: progress)
                }
            },
            onDone: { [weak self] index in
                Task { @MainActor [weak self] in
                    self?.markImageDone(fieldId: fieldId, imageIndex: index)
                }
            },
            onFail: { [weak self] index in
                Task { @MainActor [weak self] in
                    self?.markImageFailed(fieldId: fieldId, imageIndex: index)
                }
            }
        )
    }

    func getImages(for fieldId: String) -> [InspectionImage] {
        return capturedPhotos[fieldId] ?? []
    }

    private func hasPhoto(for fieldId: String) -> Bool {
        !(capturedPhotos[fieldId]?.isEmpty ?? true)
    }

    func openValidationView(for fieldId: String) {
        let fieldLabel = findFieldLabel(for: fieldId)
        selectedValidationField = ValidationFieldSelection(id: fieldId, label: fieldLabel)
    }
    
    func openCamera(for fieldId: String) {
        selectedFieldId = fieldId
        showCamera = true
    }
    
    func handleValidationSave(_ validation: FieldValidation) {
        capturedPhotos[validation.id] = validation.images
        selectedValidationField = nil
        startUploadSession(fieldId: validation.id, images: validation.images)
    }

    /// Updates capturedPhotos + starts upload session without dismissing the validation screen.
    /// Called when auto-save triggers from camera capture (no navigation change).
    func handleValidationUpdate(_ validation: FieldValidation) {
        capturedPhotos[validation.id] = validation.images
        startUploadSession(fieldId: validation.id, images: validation.images)
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
        guard var current = inspection else {
            errorMessage = "Không có dữ liệu kiểm tra để nộp"
            return
        }

        isLoading = true
        errorMessage = nil

        // Persist remote image URLs captured in this session back into the model
        for sectionIndex in current.sections.indices {
            for fieldIndex in current.sections[sectionIndex].fields.indices {
                let fieldId = current.sections[sectionIndex].fields[fieldIndex].id
                let remoteURLs = capturedPhotos[fieldId]?
                    .compactMap { $0.remoteURL?.absoluteString } ?? []
                if !remoteURLs.isEmpty {
                    current.sections[sectionIndex].fields[fieldIndex].imageURLs = remoteURLs
                }
            }
        }

        current.status = .inProgress

        do {
            try await storageService.updateInspection(current)
            inspection = current
            isSubmitted = true
            snackbarMessage = "Đã nộp báo cáo thành công!"
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
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
