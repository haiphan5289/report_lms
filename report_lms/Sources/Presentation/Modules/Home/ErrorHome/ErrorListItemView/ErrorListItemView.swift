//
//  SwiftUIView.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 7/2/26.
//

import SwiftUI

// MARK: - Error List Item View
struct ErrorListItemView: View {
    let error: ErrorItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            LMSLabel(error.headerText, style: .headline, color: .primary)
            
            // Main content HStack
            HStack(alignment: .top, spacing: 12) {
                // Image (50x50)
                Image(uiImage: error.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(LMSColor.secondaryBorder, lineWidth: 1)
                    )
                
                // Information VStack
                VStack(alignment: .leading, spacing: 4) {
                    // Defect type name
                    LMSLabel(error.defectDescription, style: .body, color: .primary)
                    
                    // HStack with severity and count
                    HStack(spacing: 8) {
                        LMSLabel(error.severity.displayName, style: .caption, color: .secondary)
                        
                        LMSLabel("•", style: .caption, color: .secondary)
                        
                        LMSLabel("\(error.affectedCount) ảnh bị ảnh hưởng", style: .caption, color: .secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: LMSColor.Shadow.subtle, radius: 4, x: 0, y: 2)
    }
}

// MARK: - Preview
#Preview("Low Severity Crack") {
    let sampleImage = UIImage(systemName: "exclamationmark.triangle") ?? UIImage()
    let errorItem = ErrorItem(
        severity: .low,
        defectType: .crack,
        image: sampleImage,
        affectedCount: 3,
        actualMeasurement: 15.5,
        maxAllowed: 20.0
    )
    ErrorListItemView(error: errorItem)
}
