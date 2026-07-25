# SwiftUI Animation Patterns

## 1. Screen Entrance (Fade + Slide Up)

```swift
// Declare state
@State private var appeared = false

// Apply to root content
content
    .opacity(appeared ? 1 : 0)
    .offset(y: appeared ? 0 : 20)
    .animation(.easeOut(duration: 0.4), value: appeared)
    .onAppear { appeared = true }
```

> For NavigationStack roots, trigger in `.task` instead of `.onAppear` to avoid re-triggering on back-navigation.

---

## 2. Staggered List Entrance

```swift
// Each row enters with index-based delay
ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
    ItemRow(item: item)
        .opacity(listAppeared ? 1 : 0)
        .offset(y: listAppeared ? 0 : 16)
        .animation(
            .easeOut(duration: 0.35).delay(Double(index) * 0.08),
            value: listAppeared
        )
}
.onAppear { listAppeared = true }
```

> Cap the delay at index 6 to avoid items appearing too late: `.delay(min(Double(index), 6) * 0.08)`.

---

## 3. Tap Scale (Spring Feedback)

### For plain SwiftUI content (no interactive child)

```swift
@GestureState private var isPressed = false

content
    .scaleEffect(isPressed ? 0.95 : 1.0)
    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
    .simultaneousGesture(
        DragGesture(minimumDistance: 0)
            .updating($isPressed) { _, state, _ in state = true }
    )
```

### For buttons with `.cdsButtonStyle` (already handles tap)

```swift
// Use simultaneousGesture so the button's own tap recogniser is not stolen
@GestureState private var isPressed = false

Button("Label") { action() }
    .cdsButtonStyle(.primary)
    .scaleEffect(isPressed ? 0.96 : 1.0)
    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
    .simultaneousGesture(
        DragGesture(minimumDistance: 0)
            .updating($isPressed) { _, state, _ in state = true }
    )
```

> **Why `simultaneousGesture`:** It never competes in the gesture arena — the button's tap fires, and scale feedback runs in parallel.

---

## 4. Float / Pulse (Empty State Icon)

```swift
@State private var floatOffset: CGFloat = -6

Image(systemName: "tray")
    .offset(y: floatOffset)
    .onAppear {
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            floatOffset = 6
        }
    }
```

---

## 5. Error Shake

```swift
@State private var shakeOffset: CGFloat = 0

targetView
    .offset(x: shakeOffset)

// Call this on validation error:
func triggerShake() {
    withAnimation(.easeInOut(duration: 0.06).repeatCount(4, autoreverses: true)) {
        shakeOffset = 8
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        withAnimation { shakeOffset = 0 }
    }
}
```

---

## 6. Success Checkmark Draw (Stroke Animation)

```swift
@State private var progress: CGFloat = 0

// Checkmark path
Circle()
    .trim(from: 0, to: progress)
    .stroke(LMSColor.success, style: StrokeStyle(lineWidth: 3, lineCap: .round))
    .frame(width: 40, height: 40)
    .rotationEffect(.degrees(-90))
    .onAppear {
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            progress = 1.0
        }
    }
```

---

## 7. Progressive Reveal (Multi-section)

```swift
@State private var heroVisible = false
@State private var cardsVisible = false
@State private var actionsVisible = false

.task {
    withAnimation(.easeOut(duration: 0.4)) { heroVisible = true }
    try? await Task.sleep(for: .milliseconds(150))
    withAnimation(.easeOut(duration: 0.4)) { cardsVisible = true }
    try? await Task.sleep(for: .milliseconds(150))
    withAnimation(.easeOut(duration: 0.4)) { actionsVisible = true }
}
```

---

## Curve Reference

| Use case | SwiftUI equivalent |
|---|---|
| Screen entry | `.easeOut(duration: 0.4)` |
| Tap scale | `.spring(response: 0.2, dampingFraction: 0.6)` |
| Spring overshoot | `.spring(response: 0.4, dampingFraction: 0.5)` |
| Float / pulse | `.easeInOut(duration: 1.8).repeatForever(autoreverses: true)` |
| Stagger per-item | `.easeOut(duration: 0.35).delay(Double(i) * 0.08)` |
| Error shake | `.easeInOut(duration: 0.06).repeatCount(4, autoreverses: true)` |
| State transition | `.easeInOut(duration: 0.35)` on `value:` |
