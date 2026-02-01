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
                
                Image(systemName: hasPhoto ? "checkmark.circle.fill" : "camera.fill")
                    .font(.system(size: 20))
                    .foregroundColor(hasPhoto ? .green : .gray)
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
        onCameraTap: {}
    )
    .padding()
}

#Preview("With Photo") {
    InspectionFieldItemView(
        fieldName: "Thông tin in trên thùng carton",
        hasPhoto: true,
        onCameraTap: {}
    )
    .padding()
}

#Preview("Long Name") {
    InspectionFieldItemView(
        fieldName: "Tổng quan chi tiết về thông tin in trên bề mặt thùng carton bên ngoài",
        hasPhoto: false,
        onCameraTap: {}
    )
    .padding()
}
