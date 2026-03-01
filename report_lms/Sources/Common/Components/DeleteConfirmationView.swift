//
//  DeleteConfirmationView.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/1/26.
//

import SwiftUI

/// Beautiful custom delete confirmation component
struct DeleteConfirmationView: View {
    // MARK: - Properties
    let title: String
    let message: String
    let confirmTitle: String
    let confirmAction: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.red)
                }
                .padding(.top, 8)
                
                // Text Content
                VStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(message)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                
                // Action Buttons
                HStack(spacing: 12) {
                    // Delete Button
                    Button(action: {
                        confirmAction()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text(confirmTitle)
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                    }
                    
                    // Cancel Button
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Hủy")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(.systemGray6))
                            .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: -5)
            )
            .padding(.horizontal, 16)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .opacity(opacity)
                .onTapGesture {
                    dismiss()
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Preview
#Preview {
    DeleteConfirmationView(
        title: "Xóa ảnh",
        message: "Bạn có chắc chắn muốn xóa ảnh này không?",
        confirmTitle: "Xóa"
    ) {
        print("Deleted")
    }
}

#Preview("Long Message") {
    DeleteConfirmationView(
        title: "Xóa tất cả ảnh",
        message: "Bạn có chắc chắn muốn xóa tất cả các ảnh đã chụp không? Hành động này không thể hoàn tác.",
        confirmTitle: "Xóa tất cả"
    ) {
        print("Deleted")
    }
}
