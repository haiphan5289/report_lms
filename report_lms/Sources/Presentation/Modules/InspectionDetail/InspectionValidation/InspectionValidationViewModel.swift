//
//  InspectionValidationViewModel.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 1/3/26.
//

import Combine
import Foundation
import SwiftUI


@MainActor
final class InspectionValidationViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Mirrors coordinator.images via Combine — SwiftUI re-renders on any change.
    @Published private(set) var images: [InspectionImage] = []
    @Published var status: ValidationStatus = .pending
    @Published var comments: String = ""
    @Published var showCamera: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showReorderMode: Bool = false
    @Published var isDirty: Bool = false
    @Published var showDeleteConfirmation: Bool = false
    @Published var isDownloading: Bool = false
    @Published var snackbarMessage: String?

    // MARK: - Internal

    let fieldLabel: String
    /// Expose coordinator so the view can pass it to child inspectors if needed.
    let coordinator: FieldUploadCoordinator

    // MARK: - Private

    private var imageIndexToDelete: Int?
    private var onSave: ((FieldValidation) -> Void)?
    private var onSilentSave: ((FieldValidation) -> Void)?
    private let initialStatus: ValidationStatus
    private let initialComments: String
    private let initialImageIds: Set<UUID>
    /// Keeps images[] in sync with coordinator.images without needing direct mutation here.
    private var imagesCancellable: AnyCancellable?

    // MARK: - Initialization

    init(
        coordinator: FieldUploadCoordinator,
        fieldLabel: String,
        initialImages: [InspectionImage] = [],
        initialStatus: ValidationStatus = .pending,
        initialComments: String = "",
        onSave: ((FieldValidation) -> Void)? = nil,
        onSilentSave: ((FieldValidation) -> Void)? = nil
    ) {
        self.coordinator = coordinator
        self.fieldLabel = fieldLabel
        self.initialStatus = initialStatus
        self.initialComments = initialComments
        self.status = initialStatus
        self.comments = initialComments

        coordinator.setInitialImages(initialImages)
        self.images = coordinator.images
        self.initialImageIds = Set(coordinator.images.map { $0.id })

        self.onSave = onSave
        self.onSilentSave = onSilentSave

        // Keep @Published images in sync — any mutation via coordinator propagates here.
        imagesCancellable = coordinator.$images
            .dropFirst()
            .assign(to: \.images, on: self)
    }

    // MARK: - Computed Properties

    var hasImages: Bool { !images.isEmpty }
    var canSave: Bool { !images.isEmpty }

    // MARK: - Camera / Image Append

    func appendImages(_ newImages: [UIImage]) {
        let iid = coordinator.inspectionId
        let fid = coordinator.fieldId
        guard !newImages.isEmpty, !iid.isEmpty else { return }
        print("[UploadSession] appendImages START fieldId=\(fid.prefix(8)) count=\(newImages.count)")

        Task { @MainActor in
            // Phase 1 — bounded parallel resize (max 4 concurrent at .utility priority)
            let chunkSize = 4
            let chunkCount = (newImages.count + chunkSize - 1) / chunkSize
            print("[UploadSession] Phase1 START chunks=\(chunkCount) priority=.utility")
            var thumbnails: [UIImage] = []
            thumbnails.reserveCapacity(newImages.count)
            var chunkStart = 0
            while chunkStart < newImages.count {
                let end = min(chunkStart + chunkSize, newImages.count)
                let tasks = newImages[chunkStart..<end].map { img in
                    Task.detached(priority: .utility) { img.resizedIfNeeded(maxDimension: 800) }
                }
                for t in tasks { thumbnails.append(await t.value) }
                chunkStart = end
            }
            print("[UploadSession] Phase1 DONE thumbnails=\(thumbnails.count)")

            var appendedIds: [UUID] = []
            for thumb in thumbnails {
                let img = InspectionImage(image: thumb)
                appendedIds.append(img.id)
                coordinator.appendImage(img)
            }
            print("[UploadSession] appended \(appendedIds.count) thumbnails → images.count=\(coordinator.images.count)")

            if status == .pending { status = .passed }
            updateDirtyState()

            // Phase 2 — serialised disk writes: release each full-res UIImage immediately
            // after its JPEG is flushed to disk, preventing 20 × ~48 MB from being pinned
            // in the closure for the entire loop (which caused OOM hangs at batch 4+).
            var pendingImages: [UIImage?] = newImages.map { Optional($0) }
            let totalCount = pendingImages.count
            Task {
                print("[UploadSession] Phase2 START serializing \(totalCount) disk writes fieldId=\(fid.prefix(8))")
                for offset in 0..<totalCount {
                    guard let img = pendingImages[offset] else {
                        print("[UploadSession] Phase2 cacheCapture FAIL offset=\(offset)/\(totalCount - 1)")
                        continue
                    }
                    let id = appendedIds[offset]
                    let thumb = await MainActor.run { coordinator.images.first(where: { $0.id == id })?.thumbnail }
                    guard let path = await InspectionImageCacheActor.shared.cacheCapture(
                        image: img, thumbnail: thumb, inspectionId: iid, fieldId: fid
                    ) else {
                        pendingImages[offset] = nil
                        print("[UploadSession] Phase2 cacheCapture FAIL offset=\(offset)/\(totalCount - 1)")
                        continue
                    }
                    pendingImages[offset] = nil  // release ~48 MB immediately after disk write
                    PendingUploadStore.shared.addPending(filePath: path, inspectionId: iid, fieldId: fid)
                    await MainActor.run {
                        coordinator.updateImageFileURL(id: id, fileURL: URL(fileURLWithPath: path))
                    }
                    print("[UploadSession] Phase2 ok offset=\(offset)/\(totalCount - 1) file=\((path as NSString).lastPathComponent)")
                }
                print("[UploadSession] Phase2 DONE → saveValidation status=\(self.status) notifyParent=false")
                saveValidation(status: self.status, notifyParent: false)
            }
        }
    }

    // MARK: - Delete

    func requestDeleteImage(at index: Int) {
        imageIndexToDelete = index
        showDeleteConfirmation = true
    }

    func requestDeleteImage(byId id: UUID) {
        guard let index = images.firstIndex(where: { $0.id == id }) else { return }
        requestDeleteImage(at: index)
    }

    func confirmDeleteImage() {
        guard let index = imageIndexToDelete,
              images.indices.contains(index) else { return }
        coordinator.removeImage(at: index)
        updateDirtyState()
        imageIndexToDelete = nil
    }

    func cancelDeleteImage() {
        imageIndexToDelete = nil
        showDeleteConfirmation = false
    }

    // MARK: - Reorder / Misc

    func moveImage(from source: IndexSet, to destination: Int) {
        coordinator.moveImages(from: source, to: destination)
        updateDirtyState()
    }

    func toggleReorderMode() { showReorderMode.toggle() }

    func openCamera() { showCamera = true }

    func updateComments(_ newComments: String) {
        comments = newComments
        updateDirtyState()
    }

    func updateDescription(_ text: String, for imageId: UUID) {
        guard let idx = images.firstIndex(where: { $0.id == imageId }) else { return }
        // Mutate through coordinator so @Published fires
        var updated = images[idx]
        updated.description = text
        // We need a coordinator method for single-image update
        coordinator.updateImage(at: idx, with: updated)
    }

    // MARK: - Save / Upload

    /// Creates a FieldValidation snapshot and enqueues upload via coordinator.
    func saveValidation(status: ValidationStatus, notifyParent: Bool = true) {
        self.status = status

        let validation = FieldValidation(
            id: coordinator.fieldId,
            status: status,
            comments: comments,
            images: coordinator.images,
            lastUpdated: Date()
        )
        saveDraft(validation)

        let toStrip = coordinator.images.filter { $0.fileURL != nil }.count
        print("[UploadSession] saveValidation status=\(status) notifyParent=\(notifyParent) images=\(coordinator.images.count) toStrip=\(toStrip) fieldId=\(coordinator.fieldId.prefix(8))")

        coordinator.enqueue(status: status, comments: comments)

        if notifyParent {
            print("[UploadSession] → onSave (parent updates + pops) fieldId=\(coordinator.fieldId.prefix(8))")
            onSave?(validation)
        } else {
            print("[UploadSession] → onSilentSave (no pop) fieldId=\(coordinator.fieldId.prefix(8))")
            onSilentSave?(validation)
        }

        isDirty = false
    }

    // MARK: - Pending Upload Retry

    func loadPendingCaptures() async {
        let inspectionId = coordinator.inspectionId
        let fieldId = coordinator.fieldId
        guard !inspectionId.isEmpty else { return }

        let paths = PendingUploadStore.shared.getPendingFilePaths(
            inspectionId: inspectionId, fieldId: fieldId
        )
        guard !paths.isEmpty else {
            print("[UploadSession] loadPendingCaptures SKIP (no pending) fieldId=\(fieldId.prefix(8))")
            return
        }
        print("[UploadSession] loadPendingCaptures found=\(paths.count) paths fieldId=\(fieldId.prefix(8))")

        let alreadyHasLocalImages = coordinator.images.contains { !$0.isRemote }
        print("[UploadSession] alreadyHasLocalImages=\(alreadyHasLocalImages) images.count=\(coordinator.images.count)")

        if !alreadyHasLocalImages {
            var loadedImages: [InspectionImage] = []
            for path in paths {
                guard let thumb = await InspectionImageCacheActor.shared.loadFromPath(path) else {
                    print("[UploadSession] loadFromPath MISS file=\((path as NSString).lastPathComponent)")
                    continue
                }
                loadedImages.append(
                    InspectionImage(fileURL: URL(fileURLWithPath: path), thumbnail: thumb)
                )
            }
            print("[UploadSession] loaded \(loadedImages.count)/\(paths.count) from disk/RAM")

            guard !loadedImages.isEmpty else {
                print("[UploadSession] disk files gone → clearField fieldId=\(fieldId.prefix(8))")
                PendingUploadStore.shared.clearField(inspectionId: inspectionId, fieldId: fieldId)
                return
            }

            coordinator.prependImages(loadedImages)
            print("[UploadSession] prepended \(loadedImages.count) → images.count=\(coordinator.images.count)")
            CacheDebugLogger.shared.log(.retryStarted(imageCount: loadedImages.count))
        }

        let retryValidation = FieldValidation(
            id: fieldId, status: status, comments: comments,
            images: coordinator.images, lastUpdated: Date()
        )
        print("[UploadSession] → onSilentSave (notify parent → startUploadSession) fieldId=\(fieldId.prefix(8))")
        onSilentSave?(retryValidation)

        print("[UploadSession] → retryPendingUploads fieldId=\(fieldId.prefix(8))")
        await coordinator.retry(status: status, comments: comments)
    }

    // MARK: - Edit / Replace

    func replaceImage(at index: Int, with newImage: UIImage) {
        print("🔍 [InspectionValidationVM] replaceImage(at: \(index))")
        guard images.indices.contains(index) else { return }
        coordinator.replaceImage(at: index, with: newImage)
        updateDirtyState()
    }

    func downloadImage(from url: URL) async throws -> UIImage {
        print("🔍 [InspectionValidationVM] downloadImage(from:)")
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

    // MARK: - Private

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

    private func updateDirtyState() {
        isDirty = status != initialStatus
            || comments != initialComments
            || Set(images.map { $0.id }) != initialImageIds
    }

    private func saveDraft(_ validation: FieldValidation) {
        let key = "draft_validation_\(coordinator.fieldId)"
        let draftData: [String: Any] = [
            "status": validation.status.rawValue,
            "comments": validation.comments,
            "imageCount": validation.images.count,
            "lastUpdated": validation.lastUpdated.timeIntervalSince1970
        ]
        if let jsonData = try? JSONSerialization.data(withJSONObject: draftData) {
            UserDefaults.standard.set(jsonData, forKey: key)
        }
    }

    func loadDraft() {
        let key = "draft_validation_\(coordinator.fieldId)"
        guard let jsonData = UserDefaults.standard.data(forKey: key),
              let draftData = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else { return }
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
        let coord = FieldUploadCoordinator(fieldId: "field1", inspectionId: "")
        return InspectionValidationViewModel(
            coordinator: coord,
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
        let coord = FieldUploadCoordinator(fieldId: "field1", inspectionId: "")
        return InspectionValidationViewModel(
            coordinator: coord,
            fieldLabel: "Carton Overview"
        )
    }
}
