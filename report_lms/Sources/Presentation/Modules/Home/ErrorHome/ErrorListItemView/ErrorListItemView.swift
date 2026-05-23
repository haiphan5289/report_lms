//
//  SwiftUIView.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 7/2/26.
//

import SwiftUI

// MARK: - ErrorItemCardView

struct ErrorItemCardView: View {
    let item: SavedErrorItem
    var cachedThumbnail: UIImage? = nil

    @GestureState private var isPressed = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnailView

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    LMSLabel(item.defectType?.displayName ?? "Không có loại lỗi", style: .headline)
                    Spacer()
                    LMSLabel(item.formattedDate, style: .caption, color: .secondary)
                }

                HStack(spacing: 8) {
                    severityBadge
                    Spacer()
                    LMSLabel("\(item.imageURLs.count) ảnh", style: .caption, color: .secondary)
                }

                if !item.comments.isEmpty {
                    LMSLabel(item.comments, style: .subheadline, color: .secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in state = true }
        )
    }

    private var thumbnailView: some View {
        Group {
            if let cached = cachedThumbnail {
                Image(uiImage: cached)
                    .resizable()
                    .scaledToFill()
            } else if let firstURL = item.imageURLs.first, let url = URL(string: firstURL) {
                CachedAsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else if phase.error != nil {
                        placeholderImage
                    } else {
                        LMSSkeleton()
                    }
                }
            } else {
                placeholderImage
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .background(LMSColor.backgroundSecondary)
    }

    private var placeholderImage: some View {
        Image(systemName: "photo")
            .font(.system(size: 24))
            .foregroundColor(LMSColor.textTertiary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(LMSColor.backgroundSecondary)
    }

    private var severityBadge: some View {
        Text(item.severity.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(severityColor.opacity(0.12))
                    .overlay(Capsule().stroke(severityColor.opacity(0.3), lineWidth: 1))
            )
            .foregroundColor(severityColor)
    }

    private var severityColor: Color {
        switch item.severity {
        case .low: return .green
        case .medium: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Preview
#Preview("Low Severity Crack") {
    ErrorItemCardView(item: SavedErrorItem(
        imageURLs: [],
        severity: .low,
        defectType: .su9,
        comments: "Nứt bề mặt ở góc trái",
        createdAt: Date()
    ))
    .padding()
    .background(Color(.systemGroupedBackground))
}
