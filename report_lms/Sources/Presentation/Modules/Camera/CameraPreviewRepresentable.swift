//
//  CameraPreviewRepresentable.swift
//  report_lms
//
//  Created by GitHub Copilot on 2/1/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI
import AVFoundation

/// SwiftUI wrapper for AVCaptureVideoPreviewLayer to display camera feed
struct CameraPreviewRepresentable: UIViewRepresentable {
    let cameraController: CameraController

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer = cameraController.previewLayer
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        // No updates needed
    }
}

// MARK: - Camera Preview View
final class CameraPreviewView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            if let previewLayer = previewLayer {
                layer.addSublayer(previewLayer)
                previewLayer.frame = bounds
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
