//
//  View+Extensions.swift
//  report_lms
//
//  Created by GitHub Copilot on 1/2/26.
//

import SwiftUI

extension View {
    /// Conditionally apply a transformation to a view
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Fade + slide-up entrance, delayed by `index` steps of `delayStep` seconds — for staggered list/form field reveals.
    func staggeredEntrance(
        visible: Bool,
        index: Int,
        delayStep: Double = 0.08,
        duration: Double = 0.35,
        offsetY: CGFloat = 16
    ) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : offsetY)
            .animation(.easeOut(duration: duration).delay(Double(index) * delayStep), value: visible)
    }
}

extension Binding where Value == CGFloat {
    /// Plays a brief horizontal shake by animating this binding, then resets it — for validation/error feedback.
    func triggerShake() {
        withAnimation(.easeInOut(duration: 0.06).repeatCount(4, autoreverses: true)) {
            wrappedValue = 8
        }
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation { wrappedValue = 0 }
        }
    }
}
