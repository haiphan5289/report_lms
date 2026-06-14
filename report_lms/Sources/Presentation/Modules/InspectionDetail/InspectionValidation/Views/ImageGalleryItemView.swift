//
//  ImageGalleryItemView.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 21/3/26.
//

import SwiftUI

// MARK: - Image Gallery Item View
struct ImageGalleryItemView: View {
    let inspectionImage: InspectionImage
    let isReorderMode: Bool
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onShare: () -> Void
    @Binding var description: String

    var inspectionId: String?
    var fieldId: String?

    @State private var appeared = false
    @GestureState private var thumbnailPressed = false

    init(
        inspectionImage: InspectionImage,
        isReorderMode: Bool,
        onDelete: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onShare: @escaping () -> Void,
        descriptionBinding: Binding<String>,
        inspectionId: String? = nil,
        fieldId: String? = nil
    ) {
        self.inspectionImage = inspectionImage
        self.isReorderMode = isReorderMode
        self.onDelete = onDelete
        self.onEdit = onEdit
        self.onShare = onShare
        self._description = descriptionBinding
        self.inspectionId = inspectionId
        self.fieldId = fieldId
    }

    @ViewBuilder
    private var inspectionImageView: some View {
        if let remoteURL = inspectionImage.remoteURL {
            if let iid = inspectionId, let fid = fieldId {
                InspectionCachedImage(url: remoteURL, inspectionId: iid, fieldId: fid) { phase in
                    imagePhaseView(phase)
                }
            } else {
                CachedAsyncImage(url: remoteURL) { phase in
                    imagePhaseView(phase)
                }
            }
        } else {
            Image(uiImage: inspectionImage.image)
                .resizable()
                .scaledToFill()
        }
    }

    @ViewBuilder
    private func imagePhaseView(_ phase: AsyncImagePhase) -> some View {
        switch phase {
        case .success(let img):
            img.resizable().scaledToFill()
        case .failure:
            Image(systemName: "photo.slash")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGray5))
        case .empty:
            LMSSkeleton()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        @unknown default:
            EmptyView()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isReorderMode {
                // Reorder mode: original layout with delete overlay
                ZStack(alignment: .topTrailing) {
                    inspectionImageView
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .padding(4)
                    }
                }
            } else {
                // Normal mode: side-by-side with entrance animation
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Color.clear.aspectRatio(4/3, contentMode: .fit)
                        inspectionImageView.scaledToFill()
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
                    .scaleEffect(thumbnailPressed ? 0.97 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.65), value: thumbnailPressed)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .updating($thumbnailPressed) { _, state, _ in state = true }
                    )

                    ImageSideActionsPanel(
                        onEdit: onEdit,
                        onShare: onShare,
                        onDelete: onDelete
                    )
                    .frame(width: 110)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.35)) { appeared = true }
                }
            }

            // Description text field (always shown)
            ZStack(alignment: .topLeading) {
                TextEditor(text: $description)
                    .frame(minHeight: 60, maxHeight: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                if description.isEmpty {
                    LMSLabel("Mô tả lỗi", style: .caption, color: .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.35).delay(0.1), value: appeared)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
    }
}
