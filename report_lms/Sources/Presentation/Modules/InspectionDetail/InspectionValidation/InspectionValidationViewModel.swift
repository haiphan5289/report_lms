//
//  InspectionValidationViewModel.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 1/3/26.
//

import Foundation
import Network
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
    private let initialImageIds: Set<UUID>
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
        self.initialImageIds = Set(initialImages.map { $0.id })
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
        guard !newImages.isEmpty, let inspectionId else { return }
        let fid = fieldId

        Task { @MainActor in
            // Phase 1 — resize in parallel on background threads (Task.detached escapes @MainActor).
            // Awaited in insertion order to preserve photo sequence.
            let resizeTasks = newImages.map { img in
                Task.detached(priority: .userInitiated) {
                    img.resizedIfNeeded(maxDimension: 800)
                }
            }

            var appendedIds: [UUID] = []
            for resizeTask in resizeTasks {
                let thumb = await resizeTask.value
                let img = InspectionImage(image: thumb)
                appendedIds.append(img.id)
                images.append(img)
            }

            // Auto-advance from .pending only; preserve any explicit user choice.
            if status == .pending { self.status = .passed }
            updateDirtyState()

            // Phase 2 — serialized disk writes: max 1 full-res (~48 MB) in RAM at a time.
            // fileURL updated by image ID so concurrent deletes don't corrupt the mapping.
            // Upload is triggered AFTER all fileURLs are set so full-res is used instead of thumbnail.
            Task {
                for (offset, img) in newImages.enumerated() {
                    let id = appendedIds[offset]
                    // Pass the Phase-1 thumbnail so cacheCapture skips a redundant 800px resize.
                    let thumb = images.first(where: { $0.id == id })?.thumbnail
                    guard let path = await InspectionImageCacheActor.shared.cacheCapture(
                        image: img, thumbnail: thumb, inspectionId: inspectionId, fieldId: fid
                    ) else { continue }
                    PendingUploadStore.shared.addPending(
                        filePath: path, inspectionId: inspectionId, fieldId: fid
                    )
                    await MainActor.run {
                        guard let idx = images.firstIndex(where: { $0.id == id }) else { return }
                        images[idx].fileURL = URL(fileURLWithPath: path)
                    }
                }
                // All fileURLs are now set — notify parent and start upload exactly once.
                saveValidation(status: self.status, notifyParent: false)
            }
        }
    }
    
    /// Show confirmation before removing image
    func requestDeleteImage(at index: Int) {
        imageIndexToDelete = index
        showDeleteConfirmation = true
    }

    func requestDeleteImage(byId id: UUID) {
        guard let index = images.firstIndex(where: { $0.id == id }) else { return }
        requestDeleteImage(at: index)
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

    func updateDescription(_ text: String, for imageId: UUID) {
        guard let idx = images.firstIndex(where: { $0.id == imageId }) else { return }
        images[idx].description = text
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
                // loadFromPath returns the thumbnail stored in RAM (or loaded from disk).
                // We keep fileURL so the upload path can read full-res from disk.
                guard let thumb = await InspectionImageCacheActor.shared.loadFromPath(path) else { continue }
                loadedImages.append(
                    InspectionImage(fileURL: URL(fileURLWithPath: path), thumbnail: thumb)
                )
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
        //
        // Slot budget (peak ~56 MB/slot during UIGraphicsImageRenderer resize):
        //   low-RAM  (<6 GB) : 3 slots → ~168 MB pipeline peak
        //   high-RAM (≥6 GB) : 5 slots WiFi / 4 slots cellular → ~280 / 224 MB peak
        //   ultra-RAM(≥8 GB) : 6 slots WiFi / 5 slots cellular → ~336 / 280 MB peak
        // Combined with app baseline (~300 MB after cache fixes) stays well under jetsam.
        let maxConcurrent = maxConcurrentSlots

        let newlyUploadedURLs: [String] = await withTaskGroup(of: (Int, String?).self) { group in
            var pending = Array(localImages.enumerated())
            var nextIndex = 0
            var results: [(Int, String)] = []

            func addJob(_ item: (offset: Int, element: InspectionImage)) {
                let idx = item.offset
                let fileURL = item.element.fileURL
                let thumbnail = item.element.thumbnail
                group.addTask {
                    // Load full-res from disk when available (preserves original quality).
                    // Falls back to thumbnail if no fileURL (legacy path).
                    let compressedData = await Task.detached(priority: .userInitiated) {
                        if let url = fileURL,
                           let data = try? Data(contentsOf: url),
                           let fullRes = UIImage(data: data) {
                            return fullRes.prepareForUpload()
                        }
                        return thumbnail?.prepareForUpload()
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
        print("🔍 [InspectionValidationVM] replaceImage(at: \(index)) — newImage size=\(newImage.size)")
        guard images.indices.contains(index) else {
            print("   - ⚠️ Index \(index) out of range (imagesCount=\(images.count))")
            return
        }
        print("   - old entry: isRemote=\(images[index].isRemote), hasFileURL=\(images[index].fileURL != nil)")
        let currentDescription = images[index].description
        // Store thumbnail in memory; full-res edited image has no fileURL (it's in-memory only).
        let thumb = newImage.resizedIfNeeded(maxDimension: 800)
        print("   - thumbnail generated: size=\(thumb.size) (⚠️ no fileURL — upload will use thumbnail quality)")
        images[index] = InspectionImage(image: thumb, description: currentDescription)
        updateDirtyState()
        print("   - ✅ Replaced at index \(index)")
    }

    func downloadImage(from url: URL) async throws -> UIImage {
        print("🔍 [InspectionValidationVM] downloadImage(from:)")
        print("   - url=...\(url.absoluteString.suffix(60))")
        if let cached = await ImageCacheActor.shared.image(for: url) {
            print("   - ✅ Cache hit (ImageCacheActor)")
            return cached
        }
        print("   - Cache miss — starting network download")
        let (data, _) = try await URLSession.shared.data(from: url)
        print("   - Downloaded \(data.count) bytes (~\(data.count / 1024)KB)")
        guard let image = UIImage(data: data) else {
            print("   - ❌ Failed to decode UIImage from data")
            throw URLError(.cannotDecodeContentData)
        }
        print("   - Decoded image size=\(image.size)")
        await ImageCacheActor.shared.store(image, for: url)
        let maxDimension: CGFloat = 2048
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let resized = resizeImage(image, maxDimension: maxDimension)
            print("   - ⚠️ Resized \(image.size) → \(resized.size) (BUG-011 guard)")
            return resized
        }
        print("   - Size within 2048px limit, no resize needed")
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

    /// Concurrent upload slots, tuned by device RAM and current network type.
    ///
    /// Peak memory per slot ≈ 56 MB (UIGraphicsImageRenderer decode + resize of a 12MP frame).
    /// Tiers keep total pipeline memory within safe jetsam margins on all devices.
    ///
    /// | RAM    | WiFi/5G | Cellular |
    /// |--------|---------|----------|
    /// | <6 GB  |    3    |    3     |
    /// | ≥6 GB  |    5    |    4     |
    /// | ≥8 GB  |    6    |    5     |
    private var maxConcurrentSlots: Int {
        let ram = ProcessInfo.processInfo.physicalMemory
        let gb: UInt64 = 1_024 * 1_024 * 1_024
        let onWiFi = isOnWiFiOrEthernet

        switch ram {
        case ..<(6 * gb):        return 3
        case (6 * gb)..<(8 * gb): return onWiFi ? 5 : 4
        default:                 return onWiFi ? 6 : 5
        }
    }

    /// Returns true when the current path is WiFi or wired Ethernet (not expensive cellular).
    private var isOnWiFiOrEthernet: Bool {
        let monitor = NWPathMonitor()
        var result = false
        let sema = DispatchSemaphore(value: 0)
        monitor.pathUpdateHandler = { path in
            result = path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet)
            sema.signal()
        }
        monitor.start(queue: DispatchQueue(label: "net.check"))
        sema.wait()
        monitor.cancel()
        return result
    }

    private func updateDirtyState() {
        isDirty = status != initialStatus ||
                  comments != initialComments ||
                  Set(images.map { $0.id }) != initialImageIds
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
                InspectionImage(image: UIImage(systemName: "photo") ?? UIImage()),
                InspectionImage(image: UIImage(systemName: "photo.fill") ?? UIImage()),
                InspectionImage(image: UIImage(systemName: "photo.circle") ?? UIImage()),
                InspectionImage(image: UIImage(systemName: "photo.circle.fill") ?? UIImage())
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
