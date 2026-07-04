//
//  CameraViewModel.swift
//  report_lms
//
//  Created by GitHub Copilot on 2/1/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI
import AVFoundation

/// A captured photo already durably written to disk at shutter-press time — the in-memory
/// `UIImage` is only for the camera review UI; `fileURL` is what survives an app kill/crash.
struct CapturedPhoto: Identifiable, Equatable {
    let id: UUID
    let image: UIImage
    let fileURL: URL

    static func == (lhs: CapturedPhoto, rhs: CapturedPhoto) -> Bool { lhs.id == rhs.id }
}

@MainActor
final class CameraViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var capturedImages: [CapturedPhoto] = []
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var zoomFactor: CGFloat = 1.0
    @Published var errorMessage: String?
    @Published var limitMessage: String?
    @Published var showPermissionAlert = false
    @Published private(set) var isFlashAvailable = false
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined

    // MARK: - Private Properties
    private let cameraController = CameraController()
    private let source: CameraSource
    private let inspectionId: String?
    private let fieldId: String?
    private var isSessionSetup = false

    var previewLayer: AVCaptureVideoPreviewLayer { cameraController.previewLayer }

    /// Where capture-time safety JPEGs are written.
    /// - When `inspectionId`/`fieldId` are known (inspection capture flow), this is the same
    ///   durable folder `InspectionImageCacheActor` owns — so a later `commitPendingCapture`
    ///   is a cheap same-folder rename, and an app-kill-before-Done orphan is recoverable via
    ///   `recoverOrphanedPendingCaptures`.
    /// - Otherwise (errorReport/general sources with no field context) this is a generic
    ///   scratch folder; those callers only want the in-memory `UIImage`, so these files are
    ///   deleted right after hand-off (see `finishedHandoff`) — same risk profile as before.
    private var pendingCapturesDir: URL {
        if let inspectionId, let fieldId {
            return InspectionImageCacheActor.fieldDirectory(inspectionId: inspectionId, fieldId: fieldId)
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("pending-captures", isDirectory: true)
    }

    // MARK: - Init
    init(source: CameraSource, inspectionId: String? = nil, fieldId: String? = nil) {
        self.source = source
        self.inspectionId = inspectionId
        self.fieldId = fieldId
    }

    // MARK: - Computed Properties
    var isAtPhotoLimit: Bool {
        guard let max = source.maxPhotos else { return false }
        return capturedImages.count >= max
    }

    var flashIcon: String {
        switch flashMode {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic.fill"
        @unknown default: return "bolt.slash.fill"
        }
    }

    // MARK: - Lifecycle
    func setupCamera() async {
        flashMode = .off
        await checkCameraPermission()

        guard cameraPermissionStatus == .authorized else {
            showPermissionAlert = true
            return
        }

        guard !isSessionSetup else { return }

        do {
            try await cameraController.setupSession()
            isSessionSetup = true
            isFlashAvailable = cameraController.isFlashAvailable
            cameraController.startSession()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopCamera() {
        cameraController.stopSession()
    }

    // MARK: - Permission Handling
    private func checkCameraPermission() async {
        cameraPermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)

        if cameraPermissionStatus == .notDetermined {
            cameraPermissionStatus = await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        }
    }

    func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }

    // MARK: - Camera Actions
    func capturePhoto() {
        guard source.allowsMultiplePhotos || capturedImages.isEmpty else { return }
        guard !isAtPhotoLimit else {
            if let max = source.maxPhotos {
                limitMessage = "Tối đa \(max) ảnh mỗi lần chụp"
            }
            return
        }

        cameraController.capturePhoto(flashMode: flashMode) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let image):
                Task { @MainActor in
                    await self.persistCapture(image)
                }
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    /// Writes the full-resolution JPEG to disk before the photo is even visible in the review
    /// strip — this is the actual fix for "kill/crash after camera → photos lost": by the time
    /// the user can dismiss the screen, every captured photo already has durable bytes on disk.
    private func persistCapture(_ image: UIImage) async {
        let id = UUID()
        guard let fileURL = await Self.writePendingFile(image: image, id: id, in: pendingCapturesDir) else {
            errorMessage = "Không thể lưu ảnh vừa chụp. Vui lòng thử lại."
            return
        }
        capturedImages.append(CapturedPhoto(id: id, image: image, fileURL: fileURL))
    }

    private static func writePendingFile(image: UIImage, id: UUID, in dir: URL) async -> URL? {
        await Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                return nil
            }
            guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
            let fileURL = dir.appendingPathComponent("pending_\(id.uuidString).jpg")
            do {
                try data.write(to: fileURL, options: .atomic)
                return fileURL
            } catch {
                return nil
            }
        }.value
    }

    func deleteImage(at index: Int) {
        guard index >= 0 && index < capturedImages.count else { return }
        let removedURL = capturedImages.remove(at: index).fileURL
        Task.detached(priority: .utility) {
            try? FileManager.default.removeItem(at: removedURL)
        }
    }

    /// Called once ownership of `capturedImages` has been resolved — either the caller took
    /// the photos (Done tapped) or the session is being discarded (Cancel, swipe-dismiss,
    /// permission-alert cancel — anything that isn't Done triggers this via `.onDisappear`).
    /// - Parameter keepFiles: `true` when the caller commits the pending JPEGs itself (the
    ///   inspection flow's `InspectionValidationViewModel.appendImages`). `false` deletes them
    ///   immediately since the caller only wanted the in-memory `UIImage`.
    func finishedHandoff(keepFiles: Bool) {
        let urls = capturedImages.map { $0.fileURL }
        capturedImages.removeAll()
        guard !keepFiles, !urls.isEmpty else { return }
        Task.detached(priority: .utility) {
            for url in urls { try? FileManager.default.removeItem(at: url) }
        }
    }

    func switchCamera() {
        Task {
            do {
                try await cameraController.switchCamera()
                isFlashAvailable = cameraController.isFlashAvailable
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func toggleFlash() {
        let nextMode: AVCaptureDevice.FlashMode
        switch flashMode {
        case .off: nextMode = .on
        case .on: nextMode = .auto
        case .auto: nextMode = .off
        @unknown default: nextMode = .off
        }
        flashMode = nextMode
    }

    func updateZoom(_ factor: CGFloat) {
        zoomFactor = factor
        do {
            try cameraController.setZoom(factor)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
