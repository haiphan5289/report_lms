//
//  CameraController.swift
//  report_lms
//
//  Created by GitHub Copilot on 2/1/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import AVFoundation
import UIKit

final class CameraController: NSObject {
    // MARK: - Properties
    private let captureSession = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.reportlms.camera.session")
    private var captureCompletion: ((Result<UIImage, Error>) -> Void)?

    private(set) lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()

    var currentCameraPosition: AVCaptureDevice.Position {
        videoDeviceInput?.device.position ?? .back
    }

    var isFlashAvailable: Bool {
        videoDeviceInput?.device.hasFlash ?? false
    }

    // MARK: - Session Management
    func setupSession() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else { return }
                do {
                    try self.configureSession()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func configureSession() throws {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            captureSession.commitConfiguration()
            throw CameraError.deviceNotAvailable
        }

        let videoInput = try AVCaptureDeviceInput(device: videoDevice)

        guard captureSession.canAddInput(videoInput) else {
            captureSession.commitConfiguration()
            throw CameraError.cannotAddInput
        }

        captureSession.addInput(videoInput)
        videoDeviceInput = videoInput

        guard captureSession.canAddOutput(photoOutput) else {
            captureSession.commitConfiguration()
            throw CameraError.cannotAddOutput
        }

        captureSession.addOutput(photoOutput)
        photoOutput.isHighResolutionCaptureEnabled = true
        captureSession.commitConfiguration()
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
        }
    }

    // MARK: - Camera Controls
    func switchCamera() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [weak self] in
                guard let self else { return }
                do {
                    try self.switchCameraSync()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func switchCameraSync() throws {
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
            captureSession.commitConfiguration()
            throw CameraError.cannotAddInput
        }

        captureSession.addInput(newInput)
        videoDeviceInput = newInput
        captureSession.commitConfiguration()
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
    func capturePhoto(flashMode: AVCaptureDevice.FlashMode, completion: @escaping (Result<UIImage, Error>) -> Void) {
        // Set completion on the calling thread (main actor from ViewModel) before dispatching.
        // The delegate always routes back to main before invoking it, so access is serialised.
        captureCompletion = completion
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            if let device = self.videoDeviceInput?.device, device.hasFlash {
                settings.flashMode = flashMode
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let result: Result<UIImage, Error>

        if let error = error {
            result = .failure(error)
        } else if let imageData = photo.fileDataRepresentation(),
                  let image = UIImage(data: imageData) {
            result = .success(image)
        } else {
            result = .failure(CameraError.imageCreationFailed)
        }

        DispatchQueue.main.async { [weak self] in
            self?.captureCompletion?(result)
            self?.captureCompletion = nil
        }
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
