//
//  InspectionFieldItemView.swift
//  report_lms
//
//  Created by GitHub Copilot on 1/2/26.
//

import SwiftUI

/// Field row with label and camera button for inspection forms
struct InspectionFieldItemView: View {
    // MARK: - Properties
    let fieldName: String
    let hasPhoto: Bool
    let images: [UIImage]
    let onCameraTap: () -> Void
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 16) {
            LMSLabel(
                fieldName,
                style: .body,
                color: .primary
            )
            
            Spacer()
            
            cameraButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Private Views
    private var cameraButton: some View {
        Button(action: onCameraTap) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 44)
                
                if let firstImage = images.first {
                    Image(uiImage: firstImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Image(systemName: hasPhoto ? "checkmark.circle.fill" : "camera.fill")
                        .font(.system(size: 20))
                        .foregroundColor(hasPhoto ? .green : .gray)
                }
            }
            .overlay(alignment: .topTrailing) {
                if images.count > 1 {
                    Text("\(images.count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(
                            Circle()
                                .fill(Color.red)
                        )
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview("Without Photo") {
    InspectionFieldItemView(
        fieldName: "Tổng quan về thùng carton",
        hasPhoto: false,
        images: [],
        onCameraTap: {}
    )
    .padding()
}

#Preview("With Photo") {
    InspectionFieldItemView(
        fieldName: "Thông tin in trên thùng carton",
        hasPhoto: true,
        images: [],
        onCameraTap: {}
    )
    .padding()
}

#Preview("Long Name") {
    InspectionFieldItemView(
        fieldName: "Tổng quan chi tiết về thông tin in trên bề mặt thùng carton bên ngoài",
        hasPhoto: false,
        images: [],
        onCameraTap: {}
    )
    .padding()
}
