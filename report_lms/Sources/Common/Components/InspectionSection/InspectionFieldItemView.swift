//
//  InspectionFieldItemView.swift
//  report_lms
//
//  Created by GitHub Copilot on 1/2/26.
//

import SwiftUI

/// Field row with label and camera button for inspection forms
struct InspectionFieldItemView: View {
    // MARK: - Constants
    private enum Layout {
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 16
        static let itemSpacing: CGFloat = 16
        static let buttonSize: CGFloat = 44
        static let iconSize: CGFloat = 20
        static let badgeFontSize: CGFloat = 12
        static let badgePadding: CGFloat = 4
        static let badgeOffset: CGFloat = 4
    }

    // MARK: - Properties
    let fieldName: String
    let hasPhoto: Bool
    let images: [InspectionImage]
    let onTextTap: () -> Void
    let onCameraTap: () -> Void

    // MARK: - Body
    var body: some View {
        HStack(spacing: Layout.itemSpacing) {
            LMSLabel(
                fieldName,
                style: .body,
                color: .primary
            )
            .frame(maxWidth: .infinity, alignment: .leading)

            cameraButton
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            onTextTap()
        }
    }

    // MARK: - Private Views
    private var cameraButton: some View {
        Button(action: onCameraTap) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: Layout.buttonSize, height: Layout.buttonSize)

                if let first = images.first {
                    if let remoteURL = first.remoteURL {
                        CachedAsyncImage(url: remoteURL) { phase in
                            if let img = phase.image {
                                img.resizable().scaledToFill()
                            } else {
                                Color(.systemGray4)
                            }
                        }
                        .frame(width: Layout.buttonSize, height: Layout.buttonSize)
                        .clipShape(Circle())
                    } else {
                        Image(uiImage: first.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: Layout.buttonSize, height: Layout.buttonSize)
                            .clipShape(Circle())
                    }
                } else {
                    Image(systemName: hasPhoto ? "checkmark.circle.fill" : "camera.fill")
                        .font(.system(size: Layout.iconSize))
                        .foregroundColor(hasPhoto ? .green : .gray)
                }
            }
            .overlay(alignment: .topTrailing) {
                if images.count > 1 {
                    badgeView
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var badgeView: some View {
        Text("\(images.count)")
            .font(.system(size: Layout.badgeFontSize, weight: .bold))
            .foregroundColor(.white)
            .padding(Layout.badgePadding)
            .background(
                Circle()
                    .fill(Color.red)
            )
            .offset(x: Layout.badgeOffset, y: -Layout.badgeOffset)
    }
}

// MARK: - Preview
#Preview("Without Photo") {
    InspectionFieldItemView(
        fieldName: "Tổng quan về thùng carton",
        hasPhoto: false,
        images: [],
        onTextTap: {},
        onCameraTap: {}
    )
    .padding()
}

#Preview("With Photo") {
    InspectionFieldItemView(
        fieldName: "Thông tin in trên thùng carton",
        hasPhoto: true,
        images: [],
        onTextTap: {},
        onCameraTap: {}
    )
    .padding()
}

#Preview("Long Name") {
    InspectionFieldItemView(
        fieldName: "Tổng quan chi tiết về thông tin in trên bề mặt thùng carton bên ngoài",
        hasPhoto: false,
        images: [],
        onTextTap: {},
        onCameraTap: {}
    )
    .padding()
}
