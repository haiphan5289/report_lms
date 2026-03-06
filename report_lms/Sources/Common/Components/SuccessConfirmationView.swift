//
//  SuccessConfirmationView.swift
//  report_lms
//
//  Created by GitHub Copilot on 5/3/26.
//

import SwiftUI

/// Beautiful custom success confirmation component
struct SuccessConfirmationView: View {
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
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.green)
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
                
                // Confirm Button
                Button(action: {
                    confirmAction()
                    dismiss()
                }) {
                    Text(confirmTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
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
    SuccessConfirmationView(
        title: "Gửi thành công",
        message: "Email báo cáo đã được gửi",
        confirmTitle: "OK"
    ) {
        print("Confirmed")
    }
}

#Preview("Long Message") {
    SuccessConfirmationView(
        title: "Lưu thành công",
        message: "Tất cả các ảnh đã được lưu vào thư viện ảnh của bạn. Bạn có thể xem lại chúng trong ứng dụng Ảnh.",
        confirmTitle: "Đóng"
    ) {
        print("Confirmed")
    }
}
