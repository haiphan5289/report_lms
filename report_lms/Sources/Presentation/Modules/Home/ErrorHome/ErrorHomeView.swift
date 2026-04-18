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
    @StateObject private var viewModel: ErrorHomeViewModel
    @State private var showErrorCamera = false
    @State private var capturedImages: [UIImage] = []
    @State private var showErrorReview = false
    @State private var scrollToTopTrigger = false

    // MARK: - Initialization
    init(viewModel: ErrorHomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            contentView
            floatingButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task {
                await viewModel.loadErrorInspections()
            }
        }
        .refreshable {
            await viewModel.loadErrorInspections()
        }
        .navigationDestination(isPresented: $showErrorCamera) {
            CameraView(source: .errorReport) { images in
                capturedImages = images
                showErrorReview = true
            }
        }
        .sheet(isPresented: $showErrorReview) {
            PhotoCaptureErrorReviewView(
                inspectionId: viewModel.inspectionId,
                initialImages: capturedImages.map { .local(image: $0) },
                onImagesUpdated: { _ in },
                onSaved: { saved, images in
                    viewModel.upsertErrorItem(saved, thumbnails: images)
                    scrollToTopTrigger.toggle()
                }
            )
        }
    }

    // MARK: - Private Views
    private var contentView: some View {
        Group {
            if viewModel.isLoading && viewModel.errorInspections.isEmpty {
                LMSLoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            } else if viewModel.errorInspections.isEmpty {
                emptyStateView
            } else {
                inspectionListView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.red)

            LMSLabel(message, style: .body, alignment: .center)

            LMSButton("Thử lại", icon: "arrow.clockwise", variant: .primary, action: {
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
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.green.opacity(0.6))
                LMSLabel("Không có lỗi nào được phát hiện", style: .body, alignment: .center)
                LMSLabel("Tất cả kiểm tra đang diễn ra tốt", style: .subheadline, color: .secondary, alignment: .center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )

            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding()
    }

    private var inspectionListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    Color.clear.frame(height: 0).id("errorList-top")
                    ForEach(viewModel.errorInspections) { item in
                        NavigationLink(value: item) {
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
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: scrollToTopTrigger) { _ in
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
        .background(Circle().fill(Color.orange))
        .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
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
