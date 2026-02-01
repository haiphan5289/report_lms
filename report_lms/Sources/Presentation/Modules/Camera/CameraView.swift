//
//  CameraView.swift
//  report_lms
//
//  Created by GitHub Copilot on 2/1/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI
import AVFoundation

// MARK: - Camera View
struct CameraView: View {
    // MARK: - Constants
    private enum Layout {
        static let buttonSize: CGFloat = 60
        static let captureButtonSize: CGFloat = 80
        static let captureButtonBorder: CGFloat = 5
        static let iconSize: CGFloat = 24
        static let topBottomPadding: CGFloat = 20
        static let horizontalPadding: CGFloat = 20
        static let controlSpacing: CGFloat = 40
        static let zoomSliderWidth: CGFloat = 200
    }
    
    // MARK: - Properties
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.dismiss) private var dismiss
    let onPhotoCaptured: (UIImage) -> Void
    
    // MARK: - Body
    var body: some View {
        ZStack {
            if viewModel.isShowingPreview, let image = viewModel.capturedImage {
                previewView(image: image)
            } else {
                cameraView
            }
        }
        .ignoresSafeArea()
        .task {
            await viewModel.setupCamera()
        }
        .onDisappear {
            viewModel.stopCamera()
        }
        .alert("Quyền truy cập camera", isPresented: $viewModel.showPermissionAlert) {
            Button("Mở Cài đặt", action: viewModel.openSettings)
            Button("Hủy", role: .cancel) { dismiss() }
        } message: {
            Text("Vui lòng cấp quyền truy cập camera trong Cài đặt để sử dụng tính năng này")
        }
        .alert("Lỗi", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
    
    // MARK: - Private Views
    private var cameraView: some View {
        VStack {
            // Camera Preview
            CameraPreviewRepresentable(cameraController: viewModel.cameraController)
            
            // Controls
            HStack(alignment: .center) {
                topControls
                bottomControls
            }
        }
    }
    
    private var topControls: some View {
        LMSButton("Hủy bỏ", variant: .ghost, size: .small) {
            dismiss()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.5))
        .cornerRadius(20)
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, Layout.topBottomPadding)
    }
    
    private var bottomControls: some View {
        VStack(spacing: 24) {
            // Zoom Slider
            HStack(spacing: 16) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                
                Slider(value: $viewModel.zoomFactor, in: 1...5, step: 0.1)
                    .frame(maxWidth: .infinity)
                    .tint(.white)
                    .onChange(of: viewModel.zoomFactor) { _, newValue in
                        viewModel.updateZoom(newValue)
                    }
                
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, Layout.horizontalPadding + 10)
            
            // Camera Controls
            HStack(spacing: 0) {
                // Flash Button (Left)
                if viewModel.cameraController.isFlashAvailable {
                    LMSButton("", icon: viewModel.flashIcon, variant: .iconOnly) {
                        viewModel.toggleFlash()
                    }
                    .foregroundColor(.white)
                    .frame(width: Layout.buttonSize, height: Layout.buttonSize)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
                } else {
                    Spacer()
                        .frame(width: Layout.buttonSize)
                }
                
                Spacer()
                
                // Capture Button (Center)
                Button(action: viewModel.capturePhoto) {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: Layout.captureButtonBorder)
                            .frame(width: Layout.captureButtonSize, height: Layout.captureButtonSize)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: Layout.captureButtonSize - 15, height: Layout.captureButtonSize - 15)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Switch Camera Button (Right)
                LMSButton("", icon: "arrow.triangle.2.circlepath.camera.fill", variant: .iconOnly) {
                    viewModel.switchCamera()
                }
                .foregroundColor(.white)
                .frame(width: Layout.buttonSize, height: Layout.buttonSize)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.bottom, Layout.topBottomPadding)
        }
    }
    
    private func previewView(image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                HStack(spacing: 40) {
                    // Retake Button
                    Button(action: viewModel.retakePhoto) {
                        VStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: Layout.iconSize))
                            Text("Chụp lại")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    // Accept Button
                    Button(action: {
                        onPhotoCaptured(image)
                        dismiss()
                    }) {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: Layout.iconSize))
                            Text("Hoàn thành")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green.opacity(0.8))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    CameraView { image in
        print("Captured image: \(image.size)")
    }
}
