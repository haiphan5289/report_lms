//
//  CameraView.swift
//  report_lms
//
//  Created by GitHub Copilot on 2/1/26.
//  Copyright © 2026 report_lms. All rights reserved.
//

import SwiftUI
import AVFoundation

// MARK: - Camera Source
enum CameraSource {
    case errorReport // Opened from ErrorHomeView report button
    case inspection // Opened from inspection flow (future use)
    case general // General photo capture (future use)

    var title: String {
        switch self {
        case .errorReport:
            return "Báo cáo lỗi"
        case .inspection:
            return "Chụp ảnh kiểm tra"
        case .general:
            return "Chụp ảnh"
        }
    }

    var allowsMultiplePhotos: Bool {
        switch self {
        case .errorReport:
            return true // Allow multiple photos for error reporting
        case .inspection:
            return false // Single photo for inspections
        case .general:
            return true // Allow multiple for general use
        }
    }
}

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
    let source: CameraSource
    let onPhotoCaptured: ([UIImage]) -> Void

    // MARK: - Body
    var body: some View {
        cameraView
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
            // Title
            Text(source.title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .padding(.top, 50)
                .padding(.bottom, 10)

            // Camera Preview
            CameraPreviewRepresentable(cameraController: viewModel.cameraController)

            // Controls
            bottomControls

            // Image List
            if !viewModel.capturedImages.isEmpty {
                imageList
            }
        }
    }
    private var bottomControls: some View {
        VStack(spacing: 24) {
            // Zoom Controls
            HStack {
                HStack(alignment: .center, spacing: 16) {
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
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Layout.horizontalPadding + 10)

            // Camera Controls
            HStack {
                // Flash Button (Left)
                if !viewModel.capturedImages.isEmpty {
                    Button(action: {
                        dismiss()
                    }, label: {
                        Text("Huỷ bỏ")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white)
                            .padding()
                    })
                    .buttonStyle(.plain)
                }

                if viewModel.cameraController.isFlashAvailable {
                    LMSButton("", icon: viewModel.flashIcon, variant: .iconOnly, action: {
                        viewModel.toggleFlash()
                    })
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

                if !viewModel.capturedImages.isEmpty {
                    Button(action: {
                        onPhotoCaptured(viewModel.capturedImages)
                        dismiss()
                    }, label: {
                        Text("Hoàn thành")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white)
                            .padding()
                    })
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var imageList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.capturedImages.indices, id: \.self) { index in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: viewModel.capturedImages[index])
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button(action: {
                            viewModel.deleteImage(at: index)
                        }, label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        })
                        .padding(4)
                    }
                }
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, 8)
        }
        .background(Color.black.opacity(0.8))
    }
}

// MARK: - Preview
#Preview("Error Report") {
    CameraView(source: .errorReport) { images in
        print("Captured images count: \(images.count)")
        if let firstImage = images.first {
            print("First image size: \(firstImage.size)")
        }
    }
}

#Preview("Inspection") {
    CameraView(source: .inspection) { images in
        print("Captured images count: \(images.count)")
        if let firstImage = images.first {
            print("First image size: \(firstImage.size)")
        }
    }
}
