//
//  CameraController.swift
//  report_lms
//
//  Created by GitHub Copilot on 2/1/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import AVFoundation
import UIKit

/// Controls AVFoundation camera session, input/output, and photo capture
///
/// Responsibilities:
/// - AVCaptureSession management
/// - Device input configuration (front/back camera)
/// - Photo output handling
/// - Flash and zoom controls
final class CameraController: NSObject {
    // MARK: - Properties
    private let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private var captureCompletion: ((Result<UIImage, Error>) -> Void)?

    var previewLayer: AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }

    var currentCameraPosition: AVCaptureDevice.Position {
        videoDeviceInput?.device.position ?? .back
    }

    var isFlashAvailable: Bool {
        videoDeviceInput?.device.hasFlash ?? false
    }

    // MARK: - Session Management
    func setupSession() async throws {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.deviceNotAvailable
        }

        let videoInput = try AVCaptureDeviceInput(device: videoDevice)

        guard captureSession.canAddInput(videoInput) else {
            throw CameraError.cannotAddInput
        }

        captureSession.addInput(videoInput)
        videoDeviceInput = videoInput

        // Add photo output
        guard captureSession.canAddOutput(photoOutput) else {
            throw CameraError.cannotAddOutput
        }

        captureSession.addOutput(photoOutput)
        photoOutput.isHighResolutionCaptureEnabled = true

        captureSession.commitConfiguration()
    }

    func startSession() {
        guard !captureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func stopSession() {
        guard captureSession.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    // MARK: - Camera Controls
    func switchCamera() async throws {
        let newPosition: AVCaptureDevice.Position = currentCameraPosition == .back ? .front : .back

        guard let newDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: newPosition
        ) else {
            throw CameraError.deviceNotAvailable
        }

        let newInput = try AVCaptureDeviceInput(device: newDevice)

        captureSession.beginConfiguration()

        if let currentInput = videoDeviceInput {
            captureSession.removeInput(currentInput)
        }

        guard captureSession.canAddInput(newInput) else {
            throw CameraError.cannotAddInput
        }

        captureSession.addInput(newInput)
        videoDeviceInput = newInput

        captureSession.commitConfiguration()
    }

    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) throws {
        guard let device = videoDeviceInput?.device, device.hasFlash else {
            throw CameraError.flashNotAvailable
        }

        try device.lockForConfiguration()
        device.flashMode = mode
        device.unlockForConfiguration()
    }

    func setZoom(_ factor: CGFloat) throws {
        guard let device = videoDeviceInput?.device else {
            throw CameraError.deviceNotAvailable
        }

        try device.lockForConfiguration()
        device.videoZoomFactor = max(1.0, min(factor, device.activeFormat.videoMaxZoomFactor))
        device.unlockForConfiguration()
    }

    // MARK: - Capture Photo
    func capturePhoto(completion: @escaping (Result<UIImage, Error>) -> Void) {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = videoDeviceInput?.device.flashMode ?? .off

        captureCompletion = completion
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            captureCompletion?(.failure(error))
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            captureCompletion?(.failure(CameraError.imageCreationFailed))
            return
        }

        captureCompletion?(.success(image))

        // Ensure session continues running after capture
        startSession()
    }
}

// MARK: - Camera Error
enum CameraError: LocalizedError {
    case deviceNotAvailable
    case cannotAddInput
    case cannotAddOutput
    case flashNotAvailable
    case imageCreationFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .deviceNotAvailable:
            return "Camera không khả dụng"
        case .cannotAddInput:
            return "Không thể thêm camera input"
        case .cannotAddOutput:
            return "Không thể thêm photo output"
        case .flashNotAvailable:
            return "Flash không khả dụng"
        case .imageCreationFailed:
            return "Không thể tạo ảnh"
        case .permissionDenied:
            return "Vui lòng cấp quyền truy cập camera trong Cài đặt"
        }
    }
}
