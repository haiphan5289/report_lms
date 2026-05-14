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
                        ProgressView()
                    }
                }
            } else {
                placeholderImage
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .background(Color.gray.opacity(0.1))
    }

    private var placeholderImage: some View {
        Image(systemName: "photo")
            .font(.system(size: 24))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))
    }

    private var severityBadge: some View {
        Text(item.severity.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(severityColor.opacity(0.15))
            .foregroundColor(severityColor)
            .cornerRadius(4)
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
