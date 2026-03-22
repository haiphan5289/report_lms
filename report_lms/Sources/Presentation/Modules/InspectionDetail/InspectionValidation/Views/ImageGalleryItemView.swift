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
    @Binding var description: String
    
    init(inspectionImage: InspectionImage, isReorderMode: Bool, onDelete: @escaping () -> Void, descriptionBinding: Binding<String>) {
        self.inspectionImage = inspectionImage
        self.isReorderMode = isReorderMode
        self.onDelete = onDelete
        self._description = descriptionBinding
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: inspectionImage.image)
                    .resizable()
                    .scaledToFill()
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
