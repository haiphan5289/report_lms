# Premium SwiftUI Patterns

Copy-paste ready. All patterns use LMS / CDS design tokens.

> Token references:
> - Colors: `LMSColor.*` (e.g. `LMSColor.primary`, `LMSColor.black`)
> - Spacing gaps: `DS.Gap.gapMedium` (16), `DS.Gap.gapSmall` (12), `DS.Gap.gapxSmall` (8)
> - Padding: `DS.Padding.paddingMedium` (16), `DS.Padding.paddingLarge` (20)
> - Corner radius: `DS.BorderRadius.radiusCard.value()` (12), `DS.BorderRadius.radiusModal.value()` (20)
> - Typography: `.cdsTextStyle(.headerSection)`, `.cdsTextStyle(.bodySection)`, `.cdsTextStyle(.caption)`

---

## 1. Hero Gradient Card

```swift
ZStack(alignment: .bottomLeading) {
    LinearGradient(
        colors: [LMSColor.primary, LMSColor.primary.opacity(0.75)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    VStack(alignment: .leading, spacing: DS.Gap.gapxSmall) {
        content
    }
    .padding(DS.Padding.paddingLarge)
}
.clipShape(RoundedRectangle(cornerRadius: DS.BorderRadius.radiusCard.value()))
.shadow(color: LMSColor.primary.opacity(0.35), radius: 20, x: 0, y: 8)
```

---

## 2. Glass / Frosted Surface (iOS 15+)

```swift
// Simple approach — use material
RoundedRectangle(cornerRadius: DS.BorderRadius.radiusCard.value())
    .fill(.ultraThinMaterial)
    .overlay(
        RoundedRectangle(cornerRadius: DS.BorderRadius.radiusCard.value())
            .stroke(Color.white.opacity(0.2), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)

// Place content on top
ZStack {
    RoundedRectangle(cornerRadius: DS.BorderRadius.radiusCard.value())
        .fill(.ultraThinMaterial)
    content.padding(DS.Padding.paddingMedium)
}
```

---

## 3. Section Header with Accent Line

```swift
HStack(spacing: DS.Gap.gapxSmall) {
    RoundedRectangle(cornerRadius: 2)
        .fill(LMSColor.primary)
        .frame(width: 3, height: 20)
    Text(title)
        .cdsTextStyle(.headerSection)
    Spacer()
}
```

---

## 4. Status Badge with Glow

```swift
Text(label)
    .cdsTextStyle(.caption)
    .foregroundColor(color)
    .padding(.horizontal, DS.Padding.paddingSmall)
    .padding(.vertical, DS.Padding.padding2xSmall)
    .background(
        Capsule()
            .fill(color.opacity(0.12))
            .overlay(
                Capsule().stroke(color.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: color.opacity(0.2), radius: 8)
    )
```

---

## 5. Cinematic Scroll (LazyVStack)

```swift
ScrollView {
    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
        // Hero section — not lazy so it renders immediately
        HeroSection()
            .padding(.bottom, DS.Padding.paddingMedium)

        Section {
            ForEach(items) { item in
                ItemRow(item: item)
                    .padding(.horizontal, DS.Padding.paddingMedium)
            }
        } header: {
            SectionHeader(title: "Section Title")
                .background(.ultraThinMaterial)
        }
    }
}
```

---

## 6. Skeleton Loading State

```swift
// CDSSkeleton from CDS — matches real content shape
VStack(spacing: DS.Gap.gapMedium) {
    // Hero placeholder
    CDSSkeleton()
        .frame(maxWidth: .infinity, minHeight: 100)
        .clipShape(RoundedRectangle(cornerRadius: DS.BorderRadius.radiusCard.value()))

    // Row placeholders
    HStack(spacing: DS.Gap.gapSmall) {
        CDSSkeleton()
            .frame(maxWidth: .infinity, minHeight: 88)
            .clipShape(RoundedRectangle(cornerRadius: DS.BorderRadius.radiusCard.value()))
        CDSSkeleton()
            .frame(maxWidth: .infinity, minHeight: 88)
            .clipShape(RoundedRectangle(cornerRadius: DS.BorderRadius.radiusCard.value()))
    }
}
.padding(.horizontal, DS.Padding.paddingMedium)
```

---

## 7. Animated Empty State

```swift
@State private var floatOffset: CGFloat = -6

// In body:
VStack(spacing: DS.Gap.gapMedium) {
    Image(systemName: "tray")
        .font(.system(size: 64))
        .foregroundColor(LMSColor.gray300)
        .offset(y: floatOffset)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                floatOffset = 6
            }
        }
    Text("Chưa có dữ liệu")
        .cdsTextStyle(.headerSection)
    Text("Thêm mục đầu tiên để bắt đầu")
        .cdsTextStyle(.bodySection)
        .foregroundColor(LMSColor.gray500)
}
.frame(maxWidth: .infinity, maxHeight: .infinity)
```

---

## 8. Progressive Content Reveal

```swift
@State private var heroVisible = false
@State private var cardsVisible = false
@State private var actionsVisible = false

// In body, apply to sections:
HeroSection()
    .opacity(heroVisible ? 1 : 0)
    .offset(y: heroVisible ? 0 : 16)

CardsSection()
    .opacity(cardsVisible ? 1 : 0)
    .offset(y: cardsVisible ? 0 : 16)

ActionsSection()
    .opacity(actionsVisible ? 1 : 0)
    .offset(y: actionsVisible ? 0 : 16)

// Trigger staggered on appear:
.task {
    withAnimation(.easeOut(duration: 0.4)) { heroVisible = true }
    try? await Task.sleep(for: .milliseconds(150))
    withAnimation(.easeOut(duration: 0.4)) { cardsVisible = true }
    try? await Task.sleep(for: .milliseconds(150))
    withAnimation(.easeOut(duration: 0.4)) { actionsVisible = true }
}
```

---

## 9. Quick Action Grid (primary CTA + secondaries)

```swift
VStack(spacing: DS.Gap.gapSmall) {
    // Primary CTA — full width
    Button("Primary Action") { onPrimaryTap() }
        .cdsButtonStyle(.primary, size: .large, sizeToFit: false)

    // Secondary CTAs — side by side
    HStack(spacing: DS.Gap.gapSmall) {
        Button("Action A") { onActionATap() }
            .cdsButtonStyle(.secondary, size: .large, sizeToFit: false)
        Button("Action B") { onActionBTap() }
            .cdsButtonStyle(.secondary, size: .large, sizeToFit: false)
    }
}
```

> Wrap each button in a tap-scale modifier (see ANIMATIONS.md Pattern `tapScale`).
> Stagger entrance: primary button first (+0ms), secondary row second (+100ms).

---

## 10. Thumb-Zone CTA

Pin the primary action to the bottom safe area so it lands in natural thumb reach.

```swift
NavigationStack {
    ScrollView { content }
}
.safeAreaInset(edge: .bottom) {
    VStack(spacing: 0) {
        Divider()
        Button("Primary Action") { onPrimaryTap() }
            .cdsButtonStyle(.primary, size: .large, sizeToFit: false)
            .padding(.horizontal, DS.Padding.paddingMedium)
            .padding(.vertical, DS.Padding.paddingSmall)
            .background(Color(UIColor.systemBackground))
    }
}
```

> Use when the screen's single CTA (submit, confirm, create) would otherwise render mid-screen. Keeps content area clean and maximises reachability.

---

## 11. Descriptive Placeholder + Format Mask

Never use generic hints. Show the expected format or a meaningful example.

```swift
// Search field — describe what can be searched
CDSSearchInput("Tìm theo tên, mã kiểm tra, ngày...", text: $query)

// Date field — show expected format
CDSTextField("Ngày", placeholder: "dd/mm/yyyy", text: $dateText)

// Phone field — show the mask
CDSTextField("Số điện thoại", placeholder: "(+84) 09x xxx xxxx", text: $phone)
    .keyboardType(.phonePad)
```

> Rule: if the field expects a specific format, show it in the placeholder. For search, list 2–3 searchable dimensions separated by commas.

---

## 12. Animated State Transition (no abrupt swap)

```swift
// Replace if/else with ZStack + opacity-based transition
ZStack {
    if isLoading {
        SkeletonView()
            .transition(.opacity)
    } else {
        ContentView()
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
.animation(.easeInOut(duration: 0.35), value: isLoading)
```
