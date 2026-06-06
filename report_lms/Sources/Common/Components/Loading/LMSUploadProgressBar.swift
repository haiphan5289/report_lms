//
//  LMSUploadProgressBar.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 6/6/26.
//

import SwiftUI

/// Thin progress bar for indicating upload activity.
///
/// Two modes:
/// - `.indeterminate` — shimmer sweep; use when upload % is unknown
/// - `.determinate(Double)` — fills to the given value (0.0–1.0)
///
/// Typical usage — show while uploading, fade out on completion:
/// ```swift
/// LMSUploadProgressBar(mode: progress >= 1 ? .determinate(1) : .indeterminate)
///     .opacity(isUploading ? 1 : 0)
///     .animation(.easeOut(duration: 0.4), value: isUploading)
/// ```
struct LMSUploadProgressBar: View {

    // MARK: - Mode

    enum Mode: Equatable {
        case indeterminate
        case determinate(Double)
    }

    // MARK: - Properties

    let mode: Mode
    var height: CGFloat = 3

    @State private var shimmerPhase: CGFloat = 0

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(LMSColor.primary.opacity(0.15))

                switch mode {
                case .indeterminate:
                    shimmerBar(totalWidth: geo.size.width)

                case .determinate(let progress):
                    Rectangle()
                        .fill(LMSColor.primary)
                        .frame(width: geo.size.width * max(0, min(1, progress)))
                        .animation(.easeOut(duration: 0.3), value: progress)
                }
            }
        }
        .frame(height: height)
        .clipped()
    }

    // MARK: - Private

    private func shimmerBar(totalWidth: CGFloat) -> some View {
        let barWidth = totalWidth * 0.35
        return Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        LMSColor.primary.opacity(0.4),
                        LMSColor.primary,
                        LMSColor.primary.opacity(0.4)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: barWidth)
            .offset(x: (totalWidth + barWidth) * shimmerPhase - barWidth)
            .onAppear {
                shimmerPhase = 0
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
            }
            .onChange(of: mode) { _ in
                shimmerPhase = 0
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1
                }
            }
    }
}

// MARK: - Preview

#Preview("Indeterminate") {
    VStack(spacing: 32) {
        LMSUploadProgressBar(mode: .indeterminate)
        LMSUploadProgressBar(mode: .indeterminate, height: 5)
    }
    .padding()
}

#Preview("Determinate") {
    VStack(spacing: 16) {
        LMSUploadProgressBar(mode: .determinate(0.3))
        LMSUploadProgressBar(mode: .determinate(0.7))
        LMSUploadProgressBar(mode: .determinate(1.0))
    }
    .padding()
}

#Preview("Dark Mode") {
    VStack(spacing: 16) {
        LMSUploadProgressBar(mode: .indeterminate)
        LMSUploadProgressBar(mode: .determinate(0.6))
    }
    .padding()
    .preferredColorScheme(.dark)
}
