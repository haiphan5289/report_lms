//
//  InspectionValidationViewModel.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 1/3/26.
//

import Foundation
import SwiftUI


@MainActor
final class InspectionValidationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var status: ValidationStatus = .pending
    @Published var comments: String = ""
    @Published var images: [InspectionImage] = []
    @Published var showCamera: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showReorderMode: Bool = false
    @Published var isDirty: Bool = false
    @Published var showDeleteConfirmation: Bool = false
    @Published var isDownloading: Bool = false
    @Published var snackbarMessage: String?

    // MARK: - Private Properties
    private var imageIndexToDelete: Int?
    private let fieldId: String
    private let inspectionId: String?
    let fieldLabel: String
    private var onSave: ((FieldValidation) -> Void)?
    private var onSilentSave: ((FieldValidation) -> Void)?
    private var onUploadComplete: (() -> Void)?
    private var onTaskCompleted: (() -> Void)?
    private var onImageProgress: (@Sendable (Int, Double) -> Void)?
    private var onImageDone: (@Sendable (Int) -> Void)?
    private var onImageFail: (@Sendable (Int) -> Void)?
    private let initialStatus: ValidationStatus
    private let initialComments: String
    private let initialImagesCount: Int
    private let storageService: InspectionStorageServiceType?
    private let uploadUseCase: UploadInspectionMediaUseCase?

    // MARK: - Initialization
    init(
        fieldId: String,
        fieldLabel: String,
        initialImages: [InspectionImage],
        initialStatus: ValidationStatus = .pending,
        initialComments: String = "",
        inspectionId: String? = nil,
        storageService: InspectionStorageServiceType? = nil,
        onSave: ((FieldValidation) -> Void)? = nil,
        onSilentSave: ((FieldValidation) -> Void)? = nil,
        onUploadComplete: (() -> Void)? = nil,
        onTaskCompleted: (() -> Void)? = nil,
        onImageProgress: (@Sendable (Int, Double) -> Void)? = nil,
        onImageDone: (@Sendable (Int) -> Void)? = nil,
        onImageFail: (@Sendable (Int) -> Void)? = nil
    ) {
        self.fieldId = fieldId
        self.fieldLabel = fieldLabel
        self.images = initialImages
        self.initialStatus = initialStatus
        self.initialComments = initialComments
        self.initialImagesCount = initialImages.count
        self.status = initialStatus
        self.comments = initialComments
        self.inspectionId = inspectionId
        self.storageService = storageService ?? Container.shared.resolve(InspectionStorageServiceType.self)
        self.uploadUseCase = Container.shared.resolve(UploadInspectionMediaUseCase.self)
        self.onSave = onSave
        self.onSilentSave = onSilentSave
        self.onUploadComplete = onUploadComplete
        self.onTaskCompleted = onTaskCompleted
        self.onImageProgress = onImageProgress
        self.onImageDone = onImageDone
        self.onImageFail = onImageFail
    }
    
    // MARK: - Computed Properties
    var hasImages: Bool {
        !images.isEmpty
    }
    
    var canSave: Bool {
        !images.isEmpty
    }
    
    // MARK: - Public Methods
    
    func appendImages(_ newImages: [UIImage]) {
        guard !newImages.isEmpty else { return }
        let wrapped = newImages.map { InspectionImage(image: $0) }
        images.append(contentsOf: wrapped)
        updateDirtyState()

        // Cache to RAM + docs-dir disk immediately so the image survives an app kill.
        // The file path is registered in PendingUploadStore so a future session can retry.
        guard let inspectionId else { return }
        let fid = fieldId
        Task {
            for img in zip(newImages, wrapped) {
                if let path = await InspectionImageCacheActor.shared.cacheCapture(
                    image: img.0, inspectionId: inspectionId, fieldId: fid
                ) {
                    PendingUploadStore.shared.addPending(
                        filePath: path, inspectionId: inspectionId, fieldId: fid
                    )
                }
            }
        }

        // Auto-save as passed after capturing photos. notifyParent: false prevents NavigationStack pop.
        saveValidation(status: .passed, notifyParent: false)
    }
    
    /// Show confirmation before removing image
    func requestDeleteImage(at index: Int) {
        imageIndexToDelete = index
        showDeleteConfirmation = true
    }
    
    /// Remove image at specific index (after confirmation)
    func confirmDeleteImage() {
        guard let index = imageIndexToDelete,
              images.indices.contains(index) else { return }
        images.remove(at: index)
        updateDirtyState()
        imageIndexToDelete = nil
    }
    
    /// Cancel image deletion
    func cancelDeleteImage() {
        imageIndexToDelete = nil
        showDeleteConfirmation = false
    }
    
    /// Move image from source to destination
    func moveImage(from source: IndexSet, to destination: Int) {
        images.move(fromOffsets: source, toOffset: destination)
        updateDirtyState()
    }
    
    /// Toggle reorder mode
    func toggleReorderMode() {
        showReorderMode.toggle()
    }
    
    /// Open camera to capture more photos
    func openCamera() {
        showCamera = true
    }
    
    /// Save validation with specified status.
    /// - Parameter notifyParent: pass `false` to skip `onSave` (prevents NavigationStack pop).
    func saveValidation(status: ValidationStatus, notifyParent: Bool = true) {
        self.status = status

        let validation = FieldValidation(
            id: fieldId,
            status: status,
            comments: comments,
            images: images,
            lastUpdated: Date()
        )

        saveDraft(validation)

        Task {
            await uploadPhotosAndUpdateField(fieldId: fieldId, images: self.images)
            await updateInspectionStatus()
            onTaskCompleted?()
        }

        if notifyParent {
            onSave?(validation)
        } else {
            onSilentSave?(validation)
        }

        isDirty = false
    }
    
    /// Update comments
    func updateComments(_ newComments: String) {
        comments = newComments
        updateDirtyState()
    }
    
    // MARK: - Pending Upload Retry

    /// Called on view appear. Loads any locally-cached images that failed to upload in a
    /// previous session (e.g. app killed mid-upload) and auto-retries the upload.
    func loadPendingCaptures() async {
        guard let inspectionId else { return }

        let paths = PendingUploadStore.shared.getPendingFilePaths(
            inspectionId: inspectionId, fieldId: fieldId
        )
        guard !paths.isEmpty else { return }

        // If the view already has local (non-remote) images, they came from capturedPhotos —
        // which already represents the pending captures written to disk. Prepending again
        // would show duplicate images. Skip prepend; still retry the upload.
        let alreadyHasLocalImages = images.contains { !$0.isRemote }

        if !alreadyHasLocalImages {
            var loadedImages: [InspectionImage] = []
            for path in paths {
                guard let img = await InspectionImageCacheActor.shared.loadFromPath(path) else { continue }
                loadedImages.append(InspectionImage(image: img))
            }

            guard !loadedImages.isEmpty else {
                // Disk files gone (iOS purged Documents — shouldn't happen but guard anyway)
                PendingUploadStore.shared.clearField(inspectionId: inspectionId, fieldId: fieldId)
                return
            }

            // Prepend so pending captures appear above existing remote images
            images.insert(contentsOf: loadedImages, at: 0)
            CacheDebugLogger.shared.log(.retryStarted(imageCount: loadedImages.count))
        }

        // Notify parent so InspectionDetailViewModel calls startUploadSession → activeUploadCount > 0.
        // Without this, FinalReportView's Send Email button won't show "Đang tải ảnh" for retry uploads.
        let retryValidation = FieldValidation(id: fieldId, status: status, comments: comments, images: images, lastUpdated: Date())
        onSilentSave?(retryValidation)

        // Auto-retry upload immediately
        await retryPendingUploads()
    }

    private func retryPendingUploads() async {
        await uploadPhotosAndUpdateField(fieldId: fieldId, images: images)
        onTaskCompleted?()
    }

    // MARK: - Private Methods

    private func uploadPhotosAndUpdateField(fieldId: String, images: [InspectionImage]) async {
        guard let inspectionId = inspectionId,
              let storageService = storageService,
              let uploadUseCase = uploadUseCase else { return }

        let existingRemoteURLs = images.compactMap { $0.isRemote ? $0.remoteURL?.absoluteString : nil }
        let localImages = images.filter { !$0.isRemote }

        // Capture callbacks before entering TaskGroup (required for @MainActor isolation).
        let progressCb = onImageProgress
        let doneCb = onImageDone
        let failCb = onImageFail

        // Pipelined compress + upload: each slot compresses one image then immediately
        // uploads it — no idle waiting for all compressions to finish first.
        // CPU (compress) and network (upload) overlap across slots.
        // For N > maxConcurrent images this saves ~25–35% vs sequential phases.
        let maxConcurrent = isHighMemoryDevice ? 4 : 3

        let newlyUploadedURLs: [String] = await withTaskGroup(of: (Int, String?).self) { group in
            var pending = Array(localImages.enumerated())
            var nextIndex = 0
            var results: [(Int, String)] = []

            func addJob(_ item: (offset: Int, element: InspectionImage)) {
                let idx = item.offset
                let image = item.element.image
                group.addTask {
                    let compressedData = await Task.detached(priority: .userInitiated) {
                        image.prepareForUpload()
                    }.value
                    guard let data = compressedData else {
                        failCb?(idx)
                        return (idx, nil)
                    }
                    do {
                        let url = try await uploadUseCase.executeWithProgress(
                            imageData: data,
                            inspectionId: inspectionId,
                            onProgress: { progress in progressCb?(idx, progress) }
                        )
                        doneCb?(idx)
                        return (idx, url)
                    } catch {
                        failCb?(idx)
                        return (idx, nil)
                    }
                }
            }

            while nextIndex < min(maxConcurrent, pending.count) {
                addJob(pending[nextIndex]); nextIndex += 1
            }
            for await (idx, url) in group {
                if let url { results.append((idx, url)) }
                if nextIndex < pending.count {
                    addJob(pending[nextIndex]); nextIndex += 1
                }
            }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        // Merge: existing remote + newly uploaded (preserves original order)
        let uploadedURLs = existingRemoteURLs + newlyUploadedURLs
        guard !uploadedURLs.isEmpty else { return }

        do {
            // Serialized write — safe when multiple fields upload concurrently.
            // Each call chains onto the previous so the fresh-cache read always
            // sees the prior field's URLs before writing back.
            try await storageService.updateFieldImageURLs(
                inspectionId: inspectionId,
                fieldId: fieldId,
                imageURLs: uploadedURLs
            )
            PendingUploadStore.shared.clearField(inspectionId: inspectionId, fieldId: fieldId)
            CacheDebugLogger.shared.log(.uploadSuccess(fieldId: fieldId))
            onUploadComplete?()
        } catch {
            // Error logged in FirestoreInspectionStorageService
        }
    }

    private func updateInspectionStatus() async {
        guard let inspectionId, let storageService else { return }
        // Partial update — only touches the `status` field in Firestore.
        // Using updateInspection (full document write) here would race with concurrent
        // updateFieldImageURLs calls from other fields and could overwrite their imageURLs.
        do {
            try await storageService.updateInspectionStatus(inspectionId: inspectionId, status: .inProgress)
        } catch {
            print("Failed to update inspection status: \(error)")
        }
    }
    
    func replaceImage(at index: Int, with newImage: UIImage) {
        guard images.indices.contains(index) else { return }
        let currentDescription = images[index].description
        images[index] = InspectionImage(image: newImage, description: currentDescription)
        updateDirtyState()
    }

    func downloadImage(from url: URL) async throws -> UIImage {
        if let cached = await ImageCacheActor.shared.image(for: url) {
            return cached
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        await ImageCacheActor.shared.store(image, for: url)
        let maxDimension: CGFloat = 2048
        if image.size.width > maxDimension || image.size.height > maxDimension {
            return resizeImage(image, maxDimension: maxDimension)
        }
        return image
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let aspectRatio = size.width / size.height
        let newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    // MARK: - Device & Network Helpers

    /// true when physical RAM >= 6 GB — allows 4 concurrent compress slots instead of 3.
    private var isHighMemoryDevice: Bool {
        ProcessInfo.processInfo.physicalMemory >= 6 * 1_024 * 1_024 * 1_024
    }

    private func updateDirtyState() {
        isDirty = status != initialStatus ||
                  comments != initialComments ||
                  images.count != initialImagesCount
    }
    
    private func saveDraft(_ validation: FieldValidation) {
        // Save to UserDefaults for draft persistence
        // Future: Migrate to CoreData or local database
        let key = "draft_validation_\(fieldId)"
        
        // Only save count and meta for now; image/description persistence is not implemented here
        let draftData = [
            "status": validation.status.rawValue,
            "comments": validation.comments,
            "imageCount": validation.images.count,
            "lastUpdated": validation.lastUpdated.timeIntervalSince1970
        ] as [String : Any]
        if let jsonData = try? JSONSerialization.data(withJSONObject: draftData) {
            UserDefaults.standard.set(jsonData, forKey: key)
        }
    }
    
    func loadDraft() {
        let key = "draft_validation_\(fieldId)"
        guard let jsonData = UserDefaults.standard.data(forKey: key),
              let draftData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return
        }
        
        if let statusString = draftData["status"] as? String,
           let status = ValidationStatus(rawValue: statusString) {
            self.status = status
        }
        
        if let comments = draftData["comments"] as? String {
            self.comments = comments
        }
    }
}

// MARK: - Preview Helpers
extension InspectionValidationViewModel {
    static func preview() -> InspectionValidationViewModel {
        InspectionValidationViewModel(
            fieldId: "field1",
            fieldLabel: "Carton Overview",
            initialImages: [
                InspectionImage(image: UIImage(systemName: "photo")!),
                InspectionImage(image: UIImage(systemName: "photo.fill")!),
                InspectionImage(image: UIImage(systemName: "photo.circle")!),
                InspectionImage(image: UIImage(systemName: "photo.circle.fill")!)
            ]
        )
    }
    
    static func previewEmpty() -> InspectionValidationViewModel {
        InspectionValidationViewModel(
            fieldId: "field1",
            fieldLabel: "Carton Overview",
            initialImages: []
        )
    }
}
