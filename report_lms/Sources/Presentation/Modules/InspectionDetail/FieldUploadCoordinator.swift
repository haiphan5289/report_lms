//
//  FieldUploadCoordinator.swift
//  report_lms
//

import Combine
import Foundation
import Network
import UIKit

/// Long-lived upload coordinator owned by InspectionDetailViewModel.
///
/// Owns the `images` array for a single inspection field so that upload tasks
/// survive InspectionValidationView being dismissed. Previously, tasks lived
/// inside InspectionValidationViewModel (@StateObject) — when the view was
/// dismissed the VM was released and any task waiting on prevTask.value would
/// hit `guard let self else { return }`, silently dropping all pending uploads.
///
/// Ownership model:
///   InspectionDetailViewModel
///     └── coordinators[fieldId] → FieldUploadCoordinator   ← LONG-LIVED
///               ├── images: [InspectionImage]               ← source of truth
///               └── currentTask: Task                       ← serial chain
///
///   InspectionValidationViewModel  (thin — UI state only)
///     └── coordinator reference   ← reads images, mutates via coordinator methods
@MainActor
final class FieldUploadCoordinator: ObservableObject {

    // MARK: - Public State

    /// Source of truth for this field's images.
    /// InspectionValidationViewModel subscribes via Combine to keep its own
    /// @Published images in sync so SwiftUI re-renders on each change.
    @Published private(set) var images: [InspectionImage] = []

    let fieldId: String
    let inspectionId: String

    // MARK: - Callbacks (wired by InspectionDetailViewModel)

    var onImageProgress: (@Sendable (Int, Double) -> Void)?
    var onImageDone:     (@Sendable (Int) -> Void)?
    var onImageFail:     (@Sendable (Int) -> Void)?
    /// Fired after each upload batch — propagates remote URLs to parent capturedPhotos.
    var onSilentSave:    ((FieldValidation) -> Void)?
    /// Fired once all URLs are written to Firestore.
    var onUploadComplete: (() -> Void)?
    /// Fired after the full task chain entry (upload + status update) completes.
    var onTaskCompleted:  (() -> Void)?

    // MARK: - Private

    private let storageService: InspectionStorageServiceType
    private let uploadUseCase: UploadInspectionMediaUseCase
    /// Serial task chain — each new upload waits for the previous to finish.
    /// Prevents concurrent Firestore writes from overwriting each other's URL lists.
    private var currentTask: Task<Void, Never>?

    // MARK: - Init

    init(
        fieldId: String,
        inspectionId: String,
        storageService: InspectionStorageServiceType? = nil,
        uploadUseCase: UploadInspectionMediaUseCase? = nil
    ) {
        self.fieldId = fieldId
        self.inspectionId = inspectionId
        self.storageService = storageService
            ?? Container.shared.resolve(InspectionStorageServiceType.self)!
        self.uploadUseCase = uploadUseCase
            ?? Container.shared.resolve(UploadInspectionMediaUseCase.self)!
    }

    // MARK: - Image Mutations (all called from InspectionValidationViewModel)

    /// Sets initial images only when coordinator is empty (e.g. first open or after eviction).
    /// Does not overwrite an in-progress upload state.
    func setInitialImages(_ initial: [InspectionImage]) {
        guard images.isEmpty else { return }
        images = initial
    }

    func appendImage(_ image: InspectionImage) {
        images.append(image)
    }

    func prependImages(_ newImages: [InspectionImage]) {
        images.insert(contentsOf: newImages, at: 0)
    }

    func updateImageFileURL(id: UUID, fileURL: URL) {
        guard let idx = images.firstIndex(where: { $0.id == id }) else { return }
        images[idx].fileURL = fileURL
    }

    func removeImage(at index: Int) {
        guard images.indices.contains(index) else { return }
        images.remove(at: index)
    }

    func moveImages(from source: IndexSet, to destination: Int) {
        images.move(fromOffsets: source, toOffset: destination)
    }

    func replaceImage(at index: Int, with newImage: UIImage) {
        guard images.indices.contains(index) else { return }
        let description = images[index].description
        images[index] = InspectionImage(image: newImage.resizedIfNeeded(maxDimension: 800),
                                        description: description)
    }

    /// Replaces the image at `index` with an already-constructed value (e.g. description update).
    func updateImage(at index: Int, with image: InspectionImage) {
        guard images.indices.contains(index) else { return }
        images[index] = image
    }

    // MARK: - Upload API

    /// Enqueues an upload, chaining after any in-flight task.
    /// Reads `self.images` AFTER the previous task completes so batch N sees
    /// batch N-1's images already marked as `.remote` — preventing re-uploads.
    func enqueue(status: ValidationStatus, comments: String) {
        let prevTask = currentTask
        currentTask = Task { [self] in
            if prevTask != nil {
                print("[UploadSession] waiting for prevTask… fieldId=\(fieldId.prefix(8))")
            }
            _ = await prevTask?.value
            if prevTask != nil {
                print("[UploadSession] prevTask done, starting upload fieldId=\(fieldId.prefix(8))")
            }
            let stripped = Self.strippedThumbnails(from: images)
            await uploadPhotosAndUpdateField(
                originalImages: images, strippedImages: stripped,
                status: status, comments: comments
            )
            print("[UploadSession] uploadPhotosAndUpdateField returned → updateInspectionStatus fieldId=\(fieldId.prefix(8))")
            await updateInspectionStatus()
            print("[UploadSession] updateInspectionStatus done → onTaskCompleted fieldId=\(fieldId.prefix(8))")
            onTaskCompleted?()
        }
    }

    /// Direct retry path (no chaining). Called by `retryAllPendingUploads`.
    func retry(status: ValidationStatus, comments: String) async {
        let toStrip = images.filter { $0.fileURL != nil }.count
        print("[UploadSession] retryPendingUploads START fieldId=\(fieldId.prefix(8)) stripping=\(toStrip) thumbnails images=\(images.count)")
        let stripped = Self.strippedThumbnails(from: images)
        await uploadPhotosAndUpdateField(
            originalImages: images, strippedImages: stripped,
            status: status, comments: comments
        )
        print("[UploadSession] uploadPhotosAndUpdateField returned → onTaskCompleted fieldId=\(fieldId.prefix(8))")
        onTaskCompleted?()
    }

    // MARK: - Private Helpers

    private static func strippedThumbnails(from images: [InspectionImage]) -> [InspectionImage] {
        images.map { img in
            guard img.fileURL != nil else { return img }
            var s = img; s.thumbnail = nil; return s
        }
    }

    /// Core upload pipeline. `originalImages` retains thumbnails for progressive
    /// release + cacheRemote; `strippedImages` (thumbnails nil) is what fills the
    /// concurrent upload slots — avoids holding N × ~2 MB in the function frame.
    private func uploadPhotosAndUpdateField(
        originalImages: [InspectionImage],
        strippedImages: [InspectionImage],
        status: ValidationStatus,
        comments: String
    ) async {
        let existingRemoteURLs = strippedImages.compactMap {
            $0.isRemote ? $0.remoteURL?.absoluteString : nil
        }
        let fullIndexedLocal = strippedImages.enumerated().filter { !$0.element.isRemote }

        // No new uploads needed — still persist descriptions in case user edited them after upload.
        guard !fullIndexedLocal.isEmpty else {
            guard !existingRemoteURLs.isEmpty else { return }
            let descriptions = strippedImages.compactMap { img -> String? in
                guard img.isRemote else { return nil }
                return img.description
            }
            do {
                try await storageService.updateFieldImageURLs(
                    inspectionId: inspectionId, fieldId: fieldId,
                    imageURLs: existingRemoteURLs, imageDescriptions: descriptions
                )
                let draft = FieldValidation(id: fieldId, status: status, comments: comments,
                                           images: images, lastUpdated: Date())
                onSilentSave?(draft)
                onUploadComplete?()
            } catch {}
            return
        }

        // O(1) lookup: full-array index → image id
        let imageIdByIndex = Dictionary(
            uniqueKeysWithValues: fullIndexedLocal.map { ($0.offset, $0.element.id) }
        )
        // Thumbnail lookup from original (stripped has nil thumbnails)
        let originalByID: [UUID: InspectionImage] = Dictionary(
            uniqueKeysWithValues: originalImages.compactMap { img in
                img.fileURL != nil ? (img.id, img) : nil
            }
        )

        let localIndices = fullIndexedLocal.map { $0.offset }
        print("[UploadSession] uploadPhotosAndUpdateField START fieldId=\(fieldId.prefix(8)) localCount=\(fullIndexedLocal.count) remoteCount=\(existingRemoteURLs.count) indices=\(Array(localIndices.prefix(5)))\(localIndices.count > 5 ? "..." : "") slots=\(maxConcurrentSlots)")

        let progressCb = onImageProgress
        let doneCb     = onImageDone
        let failCb     = onImageFail
        let maxConcurrent = maxConcurrentSlots
        let iid = inspectionId
        let fid = fieldId
        let uc = uploadUseCase

        let successfulUploads: [(offset: Int, urlString: String)] = await withTaskGroup(
            of: (Int, String?).self
        ) { group in
            let pending = fullIndexedLocal
            var nextIndex = 0
            var results: [(Int, String)] = []

            func addJob(_ item: (offset: Int, element: InspectionImage)) {
                let idx      = item.offset
                let fileURL  = item.element.fileURL
                let thumbnail = item.element.thumbnail
                group.addTask {
                    let compressedData = await Task.detached(priority: .userInitiated) {
                        if let url = fileURL,
                           let data = try? Data(contentsOf: url),
                           let fullRes = UIImage(data: data) {
                            return fullRes.prepareForUpload()
                        }
                        return thumbnail?.prepareForUpload()
                    }.value
                    guard let data = compressedData else {
                        print("[UploadSession] prepareForUpload returned nil idx=\(idx)")
                        failCb?(idx)
                        return (idx, nil)
                    }
                    do {
                        let url = try await uc.executeWithProgress(
                            imageData: data,
                            inspectionId: iid,
                            onProgress: { progress in progressCb?(idx, progress) }
                        )
                        print("[UploadSession] doneCb idx=\(idx)")
                        doneCb?(idx)
                        return (idx, url)
                    } catch {
                        print("[UploadSession] failCb idx=\(idx) error=\(error.localizedDescription.prefix(60))")
                        failCb?(idx)
                        return (idx, nil)
                    }
                }
            }

            while nextIndex < min(maxConcurrent, pending.count) {
                addJob(pending[nextIndex]); nextIndex += 1
            }
            for await (idx, urlString) in group {
                print("[UploadSession] for-await result idx=\(idx) success=\(urlString != nil)")
                if let urlString, let remoteURL = URL(string: urlString) {
                    results.append((idx, urlString))
                    if let imageId = imageIdByIndex[idx],
                       let pos = images.firstIndex(where: { $0.id == imageId }) {
                        let thumb = originalByID[imageId]?.thumbnail
                        let description = images[pos].description
                        images[pos] = InspectionImage(remoteURL: remoteURL, description: description)
                        print("[UploadSession] progressive release idx=\(idx) → remote thumb=\(thumb != nil ? "freed ~2MB" : "was nil")")
                        if let thumb {
                            Task.detached(priority: .background) {
                                await InspectionImageCacheActor.shared.cacheRemote(
                                    image: thumb, url: remoteURL,
                                    inspectionId: iid, fieldId: fid
                                )
                            }
                        }
                    }
                }
                if nextIndex < pending.count {
                    addJob(pending[nextIndex]); nextIndex += 1
                }
            }
            return results.sorted { $0.0 < $1.0 }.map { (offset: $0.0, urlString: $0.1) }
        }

        let uploadedURLs = existingRemoteURLs + successfulUploads.map { $0.urlString }
        guard !uploadedURLs.isEmpty else { return }

        let existingDescriptions = strippedImages.compactMap { img -> String? in
            guard img.isRemote else { return nil }
            return img.description
        }
        let newDescriptions = successfulUploads.map { upload -> String in
            guard let imageId = imageIdByIndex[upload.offset] else { return "" }
            return images.first(where: { $0.id == imageId })?.description ?? ""
        }
        let uploadedDescriptions = existingDescriptions + newDescriptions

        do {
            try await storageService.updateFieldImageURLs(
                inspectionId: inspectionId,
                fieldId: fieldId,
                imageURLs: uploadedURLs,
                imageDescriptions: uploadedDescriptions
            )
            PendingUploadStore.shared.clearField(inspectionId: inspectionId, fieldId: fieldId)
            print("[UploadSession] Firestore OK + clearField fieldId=\(fieldId.prefix(8)) totalURLs=\(uploadedURLs.count)")
            CacheDebugLogger.shared.log(.uploadSuccess(fieldId: fieldId))

            let updatedDraft = FieldValidation(
                id: fieldId, status: status, comments: comments,
                images: images, lastUpdated: Date()
            )
            print("[UploadSession] → onSilentSave (propagate remote URLs to parent capturedPhotos) fieldId=\(fieldId.prefix(8))")
            onSilentSave?(updatedDraft)
            print("[UploadSession] → onUploadComplete fieldId=\(fieldId.prefix(8))")
            onUploadComplete?()
        } catch {
            // Error logged in FirestoreInspectionStorageService
        }
    }

    private func updateInspectionStatus() async {
        do {
            try await storageService.updateInspectionStatus(
                inspectionId: inspectionId, status: .inProgress
            )
        } catch {
            print("Failed to update inspection status: \(error)")
        }
    }

    private var maxConcurrentSlots: Int {
        let ram = ProcessInfo.processInfo.physicalMemory
        let gb: UInt64 = 1_024 * 1_024 * 1_024
        let onWiFi = isOnWiFiOrEthernet
        switch ram {
        case ..<(6 * gb):           return 3
        case (6 * gb)..<(8 * gb):  return onWiFi ? 5 : 4
        default:                    return onWiFi ? 6 : 5
        }
    }

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
}
