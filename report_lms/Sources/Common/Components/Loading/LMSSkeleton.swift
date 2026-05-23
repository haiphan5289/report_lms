//
//  LMSSkeleton.swift
//  report_lms
//

import SwiftUI

/// Animated shimmer placeholder — use in place of ProgressView for content-shaped loading states.
struct LMSSkeleton: View {
    @State private var phase: CGFloat = -1.0

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: Color(.systemFill), location: 0),
                .init(color: Color(.systemFill).opacity(0.35), location: 0.45),
                .init(color: Color(.systemFill), location: 0.9)
            ],
            startPoint: .init(x: phase, y: 0.5),
            endPoint: .init(x: phase + 1.2, y: 0.5)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                phase = 1.5
            }
        }
    }
}

// MARK: - Inspection Card Skeleton (matches InspectionCardView shape)

struct LMSInspectionCardSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                LMSSkeleton()
                    .frame(width: 160, height: 14)
                    .clipShape(Capsule())
                LMSSkeleton()
                    .frame(width: 100, height: 12)
                    .clipShape(Capsule())
                LMSSkeleton()
                    .frame(width: 120, height: 12)
                    .clipShape(Capsule())
            }
            Spacer()
            LMSSkeleton()
                .frame(width: 60, height: 22)
                .clipShape(Capsule())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        LMSSkeleton()
            .frame(maxWidth: .infinity, minHeight: 88, maxHeight: 88)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

        LMSInspectionCardSkeleton()
        LMSInspectionCardSkeleton()
        LMSInspectionCardSkeleton()
    }
    .padding(.vertical, 12)
    .background(Color(.systemGroupedBackground))
}
