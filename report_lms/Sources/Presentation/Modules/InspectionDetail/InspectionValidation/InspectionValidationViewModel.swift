//
//  InspectionValidationViewModel.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 1/3/26.
//

import Foundation
import SwiftUI
import Network
import CoreTelephony


@MainActor
final class InspectionValidationViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var status: ValidationStatus = .pending
    @Published var comments: String = ""
    @Published var images: [InspectionImage] = []
    @Published var showCamera: Bool = false
    @Published var isLoading: Bool = false
    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0.0
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
    
    /// Save validation with specified status
    func saveValidation(status: ValidationStatus) {
        self.status = status

        let validation = FieldValidation(
            id: fieldId,
            status: status,
            comments: comments,
            images: images,
            lastUpdated: Date()
        )

        // Save draft locally
        saveDraft(validation)

        withAnimation(.easeOut(duration: 0.3)) {
            isUploading = true
            uploadProgress = 0.0
        }
        Task {
            await uploadPhotosAndUpdateField(fieldId: fieldId, images: self.images)
            await updateInspectionStatus()
            withAnimation(.easeOut(duration: 0.3)) { uploadProgress = 1.0 }
            try? await Task.sleep(nanoseconds: 500_000_000)
            withAnimation(.easeOut(duration: 0.4)) { isUploading = false }
            uploadProgress = 0.0
            onTaskCompleted?()
        }

        // Call save callback
        onSave?(validation)

        // Reset dirty state
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

        // Auto-retry upload immediately
        await retryPendingUploads()
    }

    private func retryPendingUploads() async {
        withAnimation(.easeOut(duration: 0.3)) {
            isUploading = true
            uploadProgress = 0.0
        }
        await uploadPhotosAndUpdateField(fieldId: fieldId, images: images)
        withAnimation(.easeOut(duration: 0.3)) { uploadProgress = 1.0 }
        try? await Task.sleep(nanoseconds: 500_000_000)
        withAnimation(.easeOut(duration: 0.4)) { isUploading = false }
        uploadProgress = 0.0
        onTaskCompleted?()
    }

    // MARK: - Private Methods

    private func uploadPhotosAndUpdateField(fieldId: String, images: [InspectionImage]) async {
        guard let inspectionId = inspectionId,
              let storageService = storageService,
              let uploadUseCase = uploadUseCase else { return }

        // Preserve existing remote URLs — only upload newly captured (local) images.
        let existingRemoteURLs = images.compactMap { $0.isRemote ? $0.remoteURL?.absoluteString : nil }
        let localImages = images.filter { !$0.isRemote }

        // Capture callbacks before entering the TaskGroup (required for @MainActor isolation).
        let progressCb = onImageProgress
        let doneCb = onImageDone
        let failCb = onImageFail

        // Phase 1 — Compress: run all prepareForUpload() in parallel.
        // Each prepareForUpload() peaks ~100MB (pixel buffer + renderer + JPEG output).
        // Decoupling compress from upload means upload slots never idle waiting for CPU work.
        let maxConcurrentCompress = isHighMemoryDevice ? 4 : 3
        let compressedItems: [(index: Int, data: Data)] = await withTaskGroup(of: (Int, Data?).self) { group in
            var pending = Array(localImages.enumerated())
            var nextIndex = 0
            var results: [(Int, Data)] = []

            func addCompressTask(for item: (offset: Int, element: InspectionImage)) {
                let (index, inspectionImage) = (item.offset, item.element)
                let image = inspectionImage.image
                group.addTask {
                    let data = await Task.detached(priority: .userInitiated) {
                        image.prepareForUpload()
                    }.value
                    return (index, data)
                }
            }

            while nextIndex < min(maxConcurrentCompress, pending.count) {
                addCompressTask(for: pending[nextIndex])
                nextIndex += 1
            }
            for await (index, data) in group {
                if let data {
                    results.append((index, data))
                } else {
                    failCb?(index)
                }
                if nextIndex < pending.count {
                    addCompressTask(for: pending[nextIndex])
                    nextIndex += 1
                }
            }
            return results.sorted { $0.0 < $1.0 }.map { (index: $0.0, data: $0.1) }
        }

        // Phase 2 — Upload: each slot holds only ~600KB Data (pixel buffer already released).
        // 8 slots on fast networks (WiFi/5G), 6 on slower cellular — memory cost is negligible either way.
        let maxConcurrentUpload = await isFastNetwork() ? 8 : 6
        let newlyUploadedURLs: [String] = await withTaskGroup(of: (Int, String?).self) { group in
            var nextIndex = 0
            var results: [(Int, String)] = []

            func addUploadTask(for item: (index: Int, data: Data)) {
                let (index, data) = (item.index, item.data)
                group.addTask {
                    do {
                        let url = try await uploadUseCase.executeWithProgress(
                            imageData: data,
                            inspectionId: inspectionId,
                            onProgress: { progress in progressCb?(index, progress) }
                        )
                        doneCb?(index)
                        return (index, url)
                    } catch {
                        failCb?(index)
                        return (index, nil)
                    }
                }
            }

            while nextIndex < min(maxConcurrentUpload, compressedItems.count) {
                addUploadTask(for: compressedItems[nextIndex])
                nextIndex += 1
            }
            for await (index, url) in group {
                if let url { results.append((index, url)) }
                if nextIndex < compressedItems.count {
                    addUploadTask(for: compressedItems[nextIndex])
                    nextIndex += 1
                }
            }
            return results.sorted { $0.0 < $1.0 }.map { $0.1 }
        }

        // Merge: existing remote + newly uploaded (remote first preserves original order)
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
            // Upload succeeded → clear pending set for this field.
            PendingUploadStore.shared.clearField(inspectionId: inspectionId, fieldId: fieldId)
            CacheDebugLogger.shared.log(.uploadSuccess(fieldId: fieldId))
            onUploadComplete?()
        } catch {
            // Error is already logged in FirestoreInspectionStorageService.updateInspection
        }
    }

    private func updateInspectionStatus() async {
        guard let inspectionId = inspectionId,
              let storageService = storageService,
              var inspection = storageService.getInspection(by: inspectionId) else {
            return
        }
        
        // Update status to inProgress
        inspection.status = .inProgress
        
        do {
            try await storageService.updateInspection(inspection)
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

    /// true when the current path is WiFi or 5G NR — allows 8 concurrent upload slots instead of 6.
    private func isFastNetwork() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "com.reportlms.network.check", qos: .utility)
            monitor.pathUpdateHandler = { path in
                let isWifi = path.usesInterfaceType(.wifi)
                let is5G = path.usesInterfaceType(.cellular) && {
                    let info = CTTelephonyNetworkInfo()
                    return info.serviceCurrentRadioAccessTechnology?.values.contains {
                        $0 == CTRadioAccessTechnologyNRNSA || $0 == CTRadioAccessTechnologyNR
                    } ?? false
                }()
                continuation.resume(returning: isWifi || is5G)
                monitor.cancel()
            }
            monitor.start(queue: queue)
        }
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
