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
    let onMenu: () -> Void
    @Binding var description: String

    /// Inspection context for durable docs-dir cache. nil = fall back to CachedAsyncImage.
    var inspectionId: String?
    var fieldId: String?

    init(
        inspectionImage: InspectionImage,
        isReorderMode: Bool,
        onDelete: @escaping () -> Void,
        onMenu: @escaping () -> Void,
        descriptionBinding: Binding<String>,
        inspectionId: String? = nil,
        fieldId: String? = nil
    ) {
        self.inspectionImage = inspectionImage
        self.isReorderMode = isReorderMode
        self.onDelete = onDelete
        self.onMenu = onMenu
        self._description = descriptionBinding
        self.inspectionId = inspectionId
        self.fieldId = fieldId
    }

    @ViewBuilder
    private var inspectionImageView: some View {
        if let remoteURL = inspectionImage.remoteURL {
            if let iid = inspectionId, let fid = fieldId {
                // Durable 3-tier loader: docs-dir → Caches-dir → Firebase Storage
                InspectionCachedImage(url: remoteURL, inspectionId: iid, fieldId: fid) { phase in
                    imagePhaseView(phase)
                }
            } else {
                // Generic loader (no inspection context available)
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
            Color(.systemGray5).overlay(ProgressView())
        @unknown default:
            EmptyView()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                inspectionImageView
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                if isReorderMode {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                            .padding(4)
                    }
                } else {
                    Button(action: onMenu) {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
                            .padding(8)
                    }
                }
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $description)
                    .frame(minHeight: 60, maxHeight: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                if description.isEmpty {
                    LMSLabel("Mô tả lỗi", style: .caption, color: .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}
