//
//  ErrorHomeView.swift
//  report_lms
//
//  Created by AI on February 5, 2026.
//

import SwiftUI

// MARK: - ErrorHomeView

struct ErrorHomeView: View {
    // MARK: - Properties
    @EnvironmentObject private var localizationManager: LocalizationManager
    @StateObject private var viewModel: ErrorHomeViewModel
    @State private var showErrorCamera = false
    @State private var capturedImages: [UIImage] = []
    @State private var showErrorReview = false
    @State private var hasLoadedOnce = false
    let onItemTapped: (SavedErrorItem) -> Void

    // Animation
    @State private var listAppeared = false
    @State private var floatOffset: CGFloat = -6

    // MARK: - Initialization
    init(viewModel: ErrorHomeViewModel, onItemTapped: @escaping (SavedErrorItem) -> Void = { _ in }) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onItemTapped = onItemTapped
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            contentView
            floatingButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !hasLoadedOnce else { return }
            hasLoadedOnce = true
            Task { await viewModel.loadErrorInspections() }
        }
        .refreshable {
            await viewModel.loadErrorInspections()
        }
        .fullScreenCover(isPresented: $showErrorCamera) {
            CameraView(source: .errorReport) { images in
                capturedImages = images
                showErrorReview = true
            }
        }
        .sheet(isPresented: $showErrorReview) {
            NavigationStack {
                PhotoCaptureErrorReviewView(
                    inspectionId: viewModel.inspectionId,
                    initialImages: capturedImages.map { ImageWithNote(source: .local(image: $0)) },
                    onImagesUpdated: { _ in },
                    onSaved: { saved, images in
                        viewModel.upsertErrorItem(saved, thumbnails: images)
                        viewModel.scrollToTopTrigger += 1
                    }
                )
            }
        }
    }

    // MARK: - Private Views
    private var contentView: some View {
        ZStack {
            if viewModel.isLoading && viewModel.errorInspections.isEmpty {
                errorSkeletonView
                    .transition(.opacity)
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
                    .transition(.opacity)
            } else if viewModel.errorInspections.isEmpty {
                emptyStateView
                    .transition(.opacity)
            } else {
                inspectionListView
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.35), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.35), value: viewModel.errorInspections.isEmpty)
    }

    private var errorSkeletonView: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                HStack(spacing: 12) {
                    LMSSkeleton()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 8) {
                        LMSSkeleton().frame(width: 140, height: 12).clipShape(Capsule())
                        LMSSkeleton().frame(width: 80, height: 10).clipShape(Capsule())
                        LMSSkeleton().frame(width: 120, height: 10).clipShape(Capsule())
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(color: LMSColor.shadow, radius: 4, x: 0, y: 2)
                )
                .padding(.horizontal, 16)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(LMSColor.destructive)

            LMSLabel(message, style: .body, alignment: .center)

            LMSButton(localizationManager.localize("common.retry"), icon: "arrow.clockwise", variant: .primary, action: {
                Task {
                    await viewModel.loadErrorInspections()
                }
            })
            .frame(maxWidth: 200)
            .frame(height: 44)
        }
        .padding()
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56))
                .foregroundColor(LMSColor.success.opacity(0.6))
                .offset(y: floatOffset)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                        floatOffset = 6
                    }
                }
            LMSLabel(localizationManager.localize("errorHome.empty.title"), style: .body, alignment: .center)
            LMSLabel(localizationManager.localize("errorHome.empty.subtitle"), style: .subheadline, color: .secondary, alignment: .center)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var inspectionListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    Color.clear.frame(height: 0).id("errorList-top")
                    ForEach(Array(viewModel.errorInspections.enumerated()), id: \.element.id) { index, item in
                        Button(action: {
                            print("🔍 [ErrorHomeView] Item tapped: \(item.id)")
                            print("   - Severity: \(item.severity)")
                            print("   - DefectType: \(item.defectType)")
                            onItemTapped(item)
                            print("   - Callback executed ✅")
                        }) {
                            ErrorItemCardView(item: item, cachedThumbnail: viewModel.thumbnailCache[item.id])
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(LMSColor.background)
                                .shadow(color: LMSColor.Shadow.medium, radius: 4, x: 0, y: 2)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LMSColor.Border.subtle, lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 16)
                        .opacity(listAppeared ? 1 : 0)
                        .offset(y: listAppeared ? 0 : 16)
                        .animation(
                            .easeOut(duration: 0.35).delay(Double(min(index, 6)) * 0.08),
                            value: listAppeared
                        )
                    }
                }
                .padding(.vertical, 12)
                .onAppear { listAppeared = true }
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: viewModel.scrollToTopTrigger) { _ in
                withAnimation {
                    proxy.scrollTo("errorList-top", anchor: .top)
                }
            }
        }
    }

    private var floatingButton: some View {
        Button(action: { showErrorCamera = true }) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: 56, height: 56)
        .background(Circle().fill(LMSColor.warning))
        .shadow(color: LMSColor.warning.opacity(0.45), radius: 14, x: 0, y: 6)
        .padding(.trailing, 24)
        .padding(.bottom, 24)
    }
}

// MARK: - Previews
#Preview("ErrorItemCardView - with image") {
    ErrorItemCardView(item: SavedErrorItem(
        imageURLs: ["https://picsum.photos/200"],
        severity: .medium,
        generalCondition: 7,
        defectType: .su4,
        comments: "Bề mặt bị trầy xước nghiêm trọng ở góc trái",
        createdAt: Date()
    ))
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("ErrorHomeView") {
    NavigationStack {
        ErrorHomeView(viewModel: ErrorHomeViewModel(inspectionId: "preview-id"))
    }
}

#Preview("ErrorItemCardView - no image") {
    ErrorItemCardView(item: SavedErrorItem(
        imageURLs: [],
        severity: .critical,
        defectType: .pa9,
        comments: "",
        createdAt: Date()
    ))
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("ErrorItemCardView - low severity") {
    ErrorItemCardView(item: SavedErrorItem(
        imageURLs: ["https://picsum.photos/200", "https://picsum.photos/201"],
        severity: .low,
        defectType: nil,
        comments: "",
        createdAt: Date()
    ))
    .padding()
    .background(Color(.systemGroupedBackground))
}
