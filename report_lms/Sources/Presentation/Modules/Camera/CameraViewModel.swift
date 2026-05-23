//
//  CameraViewModel.swift
//  report_lms
//
//  Created by GitHub Copilot on 2/1/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI
import AVFoundation

@MainActor
final class CameraViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var capturedImages: [UIImage] = []
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var zoomFactor: CGFloat = 1.0
    @Published var errorMessage: String?
    @Published var showPermissionAlert = false
    @Published private(set) var isFlashAvailable = false
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined

    // MARK: - Private Properties
    private let cameraController = CameraController()
    private let source: CameraSource
    private var isSessionSetup = false

    var previewLayer: AVCaptureVideoPreviewLayer { cameraController.previewLayer }

    // MARK: - Init
    init(source: CameraSource) {
        self.source = source
    }

    // MARK: - Computed Properties
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

        cameraController.capturePhoto(flashMode: flashMode) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let image):
                self.capturedImages.append(image)
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func deleteImage(at index: Int) {
        guard index >= 0 && index < capturedImages.count else { return }
        capturedImages.remove(at: index)
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
