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
    case errorReport
    case inspection
    case general

    var localizationKey: String {
        switch self {
        case .errorReport: return "camera.source.errorReport"
        case .inspection: return "camera.source.inspection"
        case .general: return "camera.source.general"
        }
    }

    var allowsMultiplePhotos: Bool {
        switch self {
        case .errorReport: return true
        case .inspection: return true
        case .general: return true
        }
    }

    /// nil = unlimited. Enforced in CameraViewModel.capturePhoto().
    var maxPhotos: Int? {
        switch self {
        case .errorReport: return nil
        case .inspection: return 20
        case .general: return nil
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
        static let titleTopPadding: CGFloat = 50
        static let titleBottomPadding: CGFloat = 10
        static let horizontalPadding: CGFloat = 20
        static let controlsVSpacing: CGFloat = 24
        static let zoomIconSpacing: CGFloat = 16
        static let thumbnailSize: CGFloat = 80
        static let thumbnailCornerRadius: CGFloat = 8
        static let thumbnailSpacing: CGFloat = 12
        static let thumbnailVerticalPadding: CGFloat = 8
    }

    // MARK: - Properties
    @StateObject private var viewModel: CameraViewModel
    @EnvironmentObject private var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss
    @State private var highlightedIndex: Int?
    @State private var controlsVisible = false
    @GestureState private var capturePressed = false
    let source: CameraSource
    private let onPhotosCaptured: ([CapturedPhoto]) -> Void
    private let keepsFilesAfterHandoff: Bool

    /// Legacy callback — receives plain `UIImage`s. The capture-time safety JPEGs are deleted
    /// right after hand-off since this caller only wants the in-memory image.
    init(source: CameraSource, onPhotoCaptured: @escaping ([UIImage]) -> Void) {
        self.source = source
        self.onPhotosCaptured = { photos in onPhotoCaptured(photos.map { $0.image }) }
        self.keepsFilesAfterHandoff = false
        _viewModel = StateObject(wrappedValue: CameraViewModel(source: source))
    }

    /// Rich callback for callers that commit the durable capture-time JPEGs themselves (see
    /// `InspectionValidationViewModel.appendImages`) — required so captured photos survive an
    /// app kill/crash between shutter press and this screen being dismissed.
    init(
        source: CameraSource,
        inspectionId: String,
        fieldId: String,
        onPhotosCaptured: @escaping ([CapturedPhoto]) -> Void
    ) {
        self.source = source
        self.onPhotosCaptured = onPhotosCaptured
        self.keepsFilesAfterHandoff = true
        _viewModel = StateObject(
            wrappedValue: CameraViewModel(source: source, inspectionId: inspectionId, fieldId: fieldId)
        )
    }

    // MARK: - Body
    var body: some View {
        cameraView
            .ignoresSafeArea()
            .task {
                await viewModel.setupCamera()
                withAnimation(.easeOut(duration: 0.5)) { controlsVisible = true }
            }
            .onDisappear {
                viewModel.stopCamera()
                // No-op if Done already claimed the photos (array is empty by then) — otherwise
                // this is a Cancel tap, swipe-dismiss, or permission-alert cancel, and any
                // pending capture files still referenced here must be cleaned up.
                viewModel.finishedHandoff(keepFiles: false)
            }
            .lmsSnackbar(message: $viewModel.limitMessage, type: .info)
            .alert(localizationManager.localize("camera.permission.title"), isPresented: $viewModel.showPermissionAlert) {
                Button(localizationManager.localize("camera.permission.openSettings"), action: viewModel.openSettings)
                Button(localizationManager.localize("common.cancel"), role: .cancel) { dismiss() }
            } message: {
                Text(localizationManager.localize("camera.permission.message"))
            }
    }

    // MARK: - Private Views
    private var cameraView: some View {
        VStack {
            Text(localizationManager.localize(source.localizationKey))
                .font(LMSTextStyle.title3.font)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.top, Layout.titleTopPadding)
                .padding(.bottom, Layout.titleBottomPadding)

            CameraPreviewRepresentable(previewLayer: viewModel.previewLayer)

            bottomControls

            if !viewModel.capturedImages.isEmpty {
                imageList
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.capturedImages.isEmpty)
    }

    private var bottomControls: some View {
        VStack(spacing: Layout.controlsVSpacing) {
            HStack {
                HStack(alignment: .center, spacing: Layout.zoomIconSpacing) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(LMSTextColor.primary.color)
                        .frame(width: 32, height: 32)

                    Slider(value: $viewModel.zoomFactor, in: 1...5, step: 0.1)
                        .frame(maxWidth: .infinity)
                        .tint(LMSColor.controlForeground)
                        .onChange(of: viewModel.zoomFactor) { _, newValue in
                            viewModel.updateZoom(newValue)
                        }

                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(LMSTextColor.primary.color)
                        .frame(width: 32, height: 32)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Layout.horizontalPadding + 10)

            HStack {
                if !viewModel.capturedImages.isEmpty {
                    Button(action: { dismiss() }, label: {
                        Text(localizationManager.localize("camera.button.cancel"))
                            .font(LMSTextStyle.caption.font)
                            .foregroundColor(LMSTextColor.primary.color)
                            .padding()
                    })
                    .buttonStyle(.plain)
                }

                if viewModel.isFlashAvailable {
                    LMSButton("", icon: viewModel.flashIcon, variant: .iconOnly, action: {
                        viewModel.toggleFlash()
                    })
                    .foregroundColor(LMSTextColor.primary.color)
                    .frame(width: Layout.buttonSize, height: Layout.buttonSize)
                    .background(LMSColor.controlBackground.opacity(0.85))
                    .clipShape(Circle())
                } else {
                    Spacer()
                        .frame(width: Layout.buttonSize)
                }

                Spacer()

                VStack(spacing: 6) {
                    Button(action: viewModel.capturePhoto, label: {
                        ZStack {
                            Circle()
                                .stroke(
                                    viewModel.isAtPhotoLimit ? Color.white.opacity(0.3) : LMSTextColor.primary.color,
                                    lineWidth: Layout.captureButtonBorder
                                )
                                .frame(width: Layout.captureButtonSize, height: Layout.captureButtonSize)

                            Circle()
                                .fill(
                                    viewModel.isAtPhotoLimit ? Color.white.opacity(0.3) : LMSTextColor.primary.color
                                )
                                .frame(width: Layout.captureButtonSize - 15, height: Layout.captureButtonSize - 15)
                        }
                    })
                    .buttonStyle(.plain)
                    .scaleEffect(capturePressed ? 0.93 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: capturePressed)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .updating($capturePressed) { _, state, _ in state = true }
                    )
                    .shadow(color: LMSTextColor.primary.color.opacity(0.18), radius: 8, x: 0, y: 4)

                    if let max = source.maxPhotos {
                        Text("\(viewModel.capturedImages.count)/\(max)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(
                                viewModel.isAtPhotoLimit ? Color.red.opacity(0.9) : Color.white.opacity(0.7)
                            )
                            .animation(.easeInOut(duration: 0.2), value: viewModel.isAtPhotoLimit)
                    }
                }

                Spacer()

                LMSButton("", icon: "arrow.triangle.2.circlepath.camera.fill", variant: .iconOnly) {
                    viewModel.switchCamera()
                }
                .foregroundColor(LMSTextColor.primary.color)
                .frame(width: Layout.buttonSize, height: Layout.buttonSize)
                .background(LMSTextColor.secondary.color.opacity(0.85))
                .clipShape(Circle())

                if !viewModel.capturedImages.isEmpty {
                    Button(action: {
                        let photos = viewModel.capturedImages
                        viewModel.finishedHandoff(keepFiles: keepsFilesAfterHandoff)
                        onPhotosCaptured(photos)
                        dismiss()
                    }, label: {
                        Text(localizationManager.localize("camera.button.done"))
                            .font(LMSTextStyle.caption.font)
                            .foregroundColor(LMSTextColor.primary.color)
                            .padding()
                    })
                    .buttonStyle(.plain)
                }
            }
        }
        .opacity(controlsVisible ? 1 : 0)
        .offset(y: controlsVisible ? 0 : 24)
        .animation(.easeOut(duration: 0.5), value: controlsVisible)
    }

    private var imageList: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Layout.thumbnailSpacing) {
                    ForEach(viewModel.capturedImages.indices, id: \.self) { index in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: viewModel.capturedImages[index].image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: Layout.thumbnailSize, height: Layout.thumbnailSize)
                                .clipShape(RoundedRectangle(cornerRadius: Layout.thumbnailCornerRadius))
                                .overlay(
                                    RoundedRectangle(cornerRadius: Layout.thumbnailCornerRadius)
                                        .stroke(Color.white, lineWidth: highlightedIndex == index ? 2 : 0)
                                )
                                .scaleEffect(highlightedIndex == index ? 1.08 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: highlightedIndex)

                            Button(action: {
                                let wasLast = index == viewModel.capturedImages.count - 1
                                viewModel.deleteImage(at: index)
                                if wasLast, !viewModel.capturedImages.isEmpty {
                                    let newLast = viewModel.capturedImages.count - 1
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        withAnimation { proxy.scrollTo(newLast, anchor: .trailing) }
                                    }
                                }
                            }, label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .background(LMSColor.black.opacity(0.6))
                                    .clipShape(Circle())
                            })
                            .padding(4)
                        }
                        .id(index)
                    }
                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.vertical, Layout.thumbnailVerticalPadding)
            }
            .onChange(of: viewModel.capturedImages.count) { oldCount, newCount in
                guard newCount > oldCount else { return }
                let newIndex = newCount - 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        proxy.scrollTo(newIndex, anchor: .trailing)
                    }
                    highlightedIndex = newIndex
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        highlightedIndex = nil
                    }
                }
            }
        }
        .background(LMSColor.black.opacity(0.8))
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
    .environmentObject(LocalizationManager.shared)
}

#Preview("Inspection") {
    CameraView(source: .inspection) { images in
        print("Captured images count: \(images.count)")
        if let firstImage = images.first {
            print("First image size: \(firstImage.size)")
        }
    }
    .environmentObject(LocalizationManager.shared)
}
