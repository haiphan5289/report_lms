//
//  CameraViewModel.swift
//  report_lms
//
//  Created by GitHub Copilot on 2/1/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI
import AVFoundation

// MARK: - Camera View Model
@MainActor
final class CameraViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var capturedImage: UIImage?
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var zoomFactor: CGFloat = 1.0
    @Published var isShowingPreview = false
    @Published var errorMessage: String?
    @Published var showPermissionAlert = false
    @Published var cameraPermissionStatus: AVAuthorizationStatus = .notDetermined
    
    // MARK: - Private Properties
    let cameraController = CameraController()
    private var isSessionSetup = false
    
    // MARK: - Computed Properties
    var flashIcon: String {
        switch flashMode {
        case .off:
            return "bolt.slash.fill"
        case .on:
            return "bolt.fill"
        case .auto:
            return "bolt.badge.automatic.fill"
        @unknown default:
            return "bolt.slash.fill"
        }
    }
    
    // MARK: - Lifecycle
    func setupCamera() async {
        await checkCameraPermission()
        
        guard cameraPermissionStatus == .authorized else {
            showPermissionAlert = true
            return
        }
        
        guard !isSessionSetup else { return }
        
        do {
            try await cameraController.setupSession()
            isSessionSetup = true
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
        cameraController.capturePhoto { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let image):
                    self?.capturedImage = image
                    self?.isShowingPreview = true
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func retakePhoto() {
        capturedImage = nil
        isShowingPreview = false
    }
    
    func switchCamera() {
        Task {
            do {
                try await cameraController.switchCamera()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func toggleFlash() {
        let nextMode: AVCaptureDevice.FlashMode
        switch flashMode {
        case .off:
            nextMode = .on
        case .on:
            nextMode = .auto
        case .auto:
            nextMode = .off
        @unknown default:
            nextMode = .off
        }
        
        do {
            try cameraController.setFlashMode(nextMode)
            flashMode = nextMode
        } catch {
            errorMessage = error.localizedDescription
        }
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
