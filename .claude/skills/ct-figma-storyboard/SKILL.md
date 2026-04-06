---
name: ct-figma-storyboard
description: Translate a Figma design into a production-ready iOS UIKit ViewController + Storyboard for Cho Tot. Use THIS SKILL when the target component needs a .storyboard file (bottom_sheet, full_screen, modal, tableview_onesection, tableview_multisection). Follows the exact ct-ai-figma-to-ios-ui.prompt.md workflow: fetch Figma MCP context → ask clarifying questions → explore existing patterns → generate ViewController.swift + .storyboard → register 5 entries in project.pbxproj. Enforces UIStackView-based storyboard layout, DSLabel/DSButton outlets, CMStaticThemeLoader theming, SnapKit for programmatic constraints, and DSBottomSheetLayout protocol. Different from ct-figma-implement-design (which uses SnapKit-only, no storyboard).
metadata:
  mcp-server: figma
---

# Figma → iOS UIKit Storyboard Implementation

## Overview

This skill translates a Figma design node into a production-ready **ViewController + Storyboard** pair for Cho Tot iOS, following the exact conventions of the project. It covers:

- Figma MCP context fetching and visual screenshot
- Clarifying questions before writing any code
- Pattern exploration from canonical reference storyboards
- ViewController `.swift` generation (DSBottomSheetLayout, CMStaticThemeLoader, IBOutlets, IBActions)
- Storyboard `.storyboard` generation (UIStackView-based, DSLabel/DSButton custom classes)
- Xcode project registration (`project.pbxproj` — 5 entries)

## Input Format

The user must provide:

```
FIGMA_URL: <Figma node URL, dev mode preferred>
MODULE_PATH: <Target folder path, e.g. ChoTot/Features/Job/VerticalizePos/Presentation/Ver2/Pos>
COMPONENT_TYPE: <bottom_sheet | full_screen | modal | view_component | tableview_onesection | tableview_multisection>
```

## Required Workflow

**Follow all steps in order. Do not skip any step.**

---

### Step 0 — Verify Figma MCP Server

Before anything else:

1. Use `ToolSearch` to load all Figma MCP tools (they are deferred — search for `mcp__figma`)
2. Call `mcp__figma__get_screenshot` with the node ID extracted from `FIGMA_URL`
3. If the call **succeeds**, proceed to Step 1
4. If the call **fails**, stop and report:

```
❌ Figma MCP Server is not reachable.
Fix:
  1. Open VS Code Output panel → select "MCP: figma"
  2. Cmd+Shift+P → "MCP: Restart Server" → figma
  3. Verify scripts/figma-mcp-proxy/server.js exists
  4. Re-run this skill
```

> Do NOT generate any code if the MCP server is unreachable — design context will be missing.

---

### Step 1 — Fetch Figma Design Context

Extract `file_key` and `node_id` from `FIGMA_URL`:

- **file_key**: segment after `/design/` (e.g. `GlkeqMpiIEcPpIAoHO6FKL`)
- **node_id**: value of `node-id` query param (e.g. `2703-10882`)

Then call **both in parallel**:

1. `mcp__figma__get_design_context(file_key, node_id, depth=4)` — extracts layout, colors, typography, component tree
2. `mcp__figma__get_screenshot(file_key, node_id)` — visual reference (source of truth for fidelity)

Analyze the result:
- Identify sections: header, body, footer
- Note layout direction, spacing, fills, font sizes/weights
- Identify interactive elements (buttons, close icon)

#### Step 1b — Extract Overridden Text Content (MANDATORY)

After getting the design context, inspect the `overrides` array in the raw JSON response.

For **every** override entry where `overriddenFields` contains `"characters"`, the text content of that node has been customised and **will NOT appear** in the parent's `get_design_context` result — you must fetch it separately.

**Algorithm:**
1. Collect all override IDs where `overriddenFields` includes `"characters"`
2. Also collect IDs of button instances where `overriddenFields` includes `"componentProperties"` (button label text is stored as a `TEXT` component property — key pattern: `"↳ Input Text#..."`)
3. Fetch all collected node IDs **in parallel** using `mcp__figma__get_design_context(file_key, node_id, depth=2)`
4. From TEXT nodes → read the `characters` field for label default text
5. From button INSTANCE nodes → read `componentProperties["↳ Input Text#..."].value` for button title

**Use these extracted strings as default values everywhere:**
- In `.storyboard`: set `text="..."` on `<label>` elements, `title="..."` on `<button state key="normal">`
- In `configureUI()`: use `?? "extracted text"` fallback on every `.text` / `setTitle(_:for:)` call

> If `overrides` is empty or no `"characters"` overrides exist, use the `characters` value already visible in the `get_design_context` structure output.

---

### Step 1c — Find Existing Similar UI (Ask Before Creating)

**First, ask the user:**

```
Would you like me to search the codebase for existing UI components
similar to this Figma design, so you can reuse or extend them instead
of creating from scratch? (yes / no)
```

> If the user answers **no** — skip this step entirely and proceed to Step 2.

---

If the user answers **yes**, search the codebase for existing components that visually match the Figma design. This prevents duplication and enforces the "Reuse Over Recreation" principle.

**Search strategy (module-first, then expand):**

1. **Within the same module** (`MODULE_PATH`): Search for ViewControllers or Views with the same `COMPONENT_TYPE` (e.g., other bottom sheets, warning dialogs, two-button footers)
2. **Cross-module** (if nothing found): Expand search to sibling AppFeatures modules
3. **Key signals to match:**
   - Same structural pattern: header + body + footer, or icon + title + description + buttons
   - Same interactive element count: single button vs. two-button footer
   - Same icon type: warning icon, info icon, close button
   - Similar TypoToken hierarchy used (e.g., `Header.Section` + `Body.Section`)

**Search commands to run:**
```
# Find similar bottom sheets / warning dialogs in same module
grep -r "DSBottomSheetLayout" MODULE_PATH --include="*.swift" -l

# Find ViewControllers with two-button footer pattern
grep -r "secondaryButton\|primaryButton" MODULE_PATH --include="*.swift" -l

# Find warning/notice-style components cross-module
grep -r "warningFill\|noticeShare\|warningMessage" AppFeatures --include="*.swift" -l
```

**Present candidates to the user:**

If one or more matches are found, show:

```
Found similar existing UI:
  • CRNoticeShareAdViewController.swift (CTCorePayment) — bottom sheet with close + 2-button footer
  • JBWarningViewController.swift (CTJOB) — icon + title + description + primary button

→ Do you want to:
  [A] Reuse / extend one of these components
  [B] Create a new component from scratch
```

If no matches are found, inform the user and proceed directly to Step 2.

---

### Step 2 — Clarifying Questions (Ask BEFORE Writing Code)

Ask the user only the minimum required before generating files:

- **Button actions**: What does each button/close icon do? (dismiss, navigate, callback?)
- **File name**: What should the ViewController and storyboard be named? (e.g. `JBWarningMessage`)
- **Subfolder**: Which subfolder within `MODULE_PATH`? (confirm or ask if ambiguous)

Do NOT ask about design tokens, spacing, or colors — extract those from Figma.

---

### Step 3 — Explore Existing Patterns

Before writing code, search the module for:

1. How `DSBottomSheetLayout` is used in sibling ViewControllers
2. How `configureUI()` applies `DS.TypoToken.*` and `DS.Button.*`
3. Which theme is used: `CMStaticThemeLoader.jobTheme`, `.defaultTheme`, `.posTheme`, etc.
4. Whether SnapKit is used for programmatic constraints (always yes)

Then read the **canonical reference** by `COMPONENT_TYPE`:

| COMPONENT_TYPE | Reference files to read |
|---|---|
| `bottom_sheet` | `AppFeatures/CTCorePayment/CTCorePayment/Features/CheckoutPage/NoticeShareAd/CRNoticeShareAd.storyboard` + `CRNoticeShareAdViewController.swift` |
| `tableview_onesection` | `AppFeatures/CTCorePayment/CTCorePayment/Features/DongTot/TopupDongtot/HighValuePackage/CRHighValuePackage.storyboard` + `CRHighValuePackageViewController.swift` |
| `tableview_multisection` | `AppFeatures/CTPTY/CTPTY/Features/Subscription/SubscriptionSK/PTSubscriptionSK.storyboard` + `PTSubscriptionSKViewController.swift` |
| `full_screen` / `modal` | Search for a sibling storyboard in the same module folder |

Replicate the reference's StackView structure exactly before writing the new storyboard.

---

### Step 4 — Generate ViewController (.swift)

Use this exact structure:

```swift
//
//  <Name>ViewController.swift
//  ChoTot
//
//  Created by <git config user.name> on <current date from mcp__time__get_current_time>.
//  Copyright © 2024 Cho Tot. All rights reserved.
//

import UIKit
import SnapKit
import CTDesignSystem
import CTCommon
import CTAsset

final class <Name>ViewController: UIViewController, DSBottomSheetLayout {

    // MARK: - Outlets
    @IBOutlet private weak var titleLabel: DSLabel!
    @IBOutlet private weak var bodyTitleLabel: DSLabel!
    @IBOutlet private weak var descriptionLabel: DSLabel!
    @IBOutlet private weak var secondaryButton: DSButton!
    @IBOutlet private weak var primaryButton: DSButton!

    // MARK: - Properties
    var on<SecondaryAction>: (() -> Void)?
    var on<PrimaryAction>: (() -> Void)?
    private let theme = CMStaticThemeLoader.<moduleTheme>

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
    }

    deinit { Logger.print("\(self) deallocated.") }

    // MARK: - Private Methods
    private func configureUI() {
        titleLabel.setStyle(DS.TypoToken.Header.Section(color: theme.text.textPrimary.color))
        titleLabel.text = "<title from Figma>"

        bodyTitleLabel.setStyle(DS.TypoToken.Header.Page(color: theme.text.textPrimary.color))
        bodyTitleLabel.text = "<body title from Figma>"

        descriptionLabel.setStyle(DS.TypoToken.Body.Section(color: theme.text.textSecondary.color))
        descriptionLabel.text = "<description from Figma>"

        secondaryButton.setStyle(DS.Button.secondary(size: .medium, themeType: theme.type))
        secondaryButton.setTitle("<label>", for: .normal)

        primaryButton.setStyle(DS.Button.primary(size: .medium, themeType: theme.type))
        primaryButton.setTitle("<label>", for: .normal)
    }

    // MARK: - Actions
    @IBAction private func didTapSecondaryButton(_ sender: Any) {
        dismiss(animated: true) { [weak self] in self?.on<SecondaryAction>?() }
    }

    @IBAction private func didTapPrimaryButton(_ sender: Any) {
        dismiss(animated: true) { [weak self] in self?.on<PrimaryAction>?() }
    }

    @IBAction private func didTapClose(_ sender: Any) {
        dismiss(animated: true)
    }
}
```

**Rules:**
- Always `DSLabel`, `DSButton` — never `UILabel`, `UIButton` directly in style calls
- Match `DS.TypoToken.*` to Figma font size/weight (see token table below)
- Match `DS.Button.*` to Figma button fill (primary = yellow `#FFD400`, secondary = white/bordered)
- Use `CTAssetSystemIcon.*` for icons (`warningFill24px`, `closeOutline24px`, etc.)
- SnapKit for any programmatic constraints only; use IBOutlets for storyboard views
- Dismiss pattern: `dismiss(animated: true) { [weak self] in self?.on<Action>?() }`

---

### Step 5 — Generate Storyboard (.storyboard)

> ⚠️ Layout MUST use `UIStackView` as the primary structure driver.
> Never chain sections with leading/top/trailing/bottom anchor constraints.
> Replicate the canonical reference storyboard StackView structure exactly.

**Outer StackView structure (bottom_sheet pattern):**

```
Root View (white background)
└── mainStackView (vertical, spacing=0)
    → pinned to safeArea: top/leading/trailing + bottom >= 0
    ├── Drawer Header (UIView, fixed height 48)
    │    ├── Title (DSLabel, leading=16, trailing to closeButton-8, centerY)
    │    ├── Close Button (UIButton, trailing=16, centerY, 24x24)
    │    └── Separator (UIView, height=1, bottom=0, full width)
    ├── Body Container (UIView) ← NOT a StackView — just a plain UIView
    │    └── Body StackView (UIStackView, vertical, alignment=center, spacing=16)
    │         pinned: top=24, leading=16, trailing=16, bottom=24
    │         ├── Illustration (UIImageView, 80x80 explicit constraints)
    │         └── Content StackView (vertical, spacing=8)
    │              ├── Body Title (DSLabel, textAlignment=center, numberOfLines=0)
    │              └── Description (DSLabel, textAlignment=center, numberOfLines=0)
    └── Footer (UIView)
         ├── Divider (UIView, height=1, top=0, full width)
         └── Button StackView (horizontal, distribution=fillEqually, spacing=8)
              top=16, leading=16, trailing=16, height=40, bottom=16
              ├── Secondary Button (DSButton)
              └── Primary Button (DSButton)
```

> ⚠️ **Body padding rule:** NEVER use `layoutMarginsRelativeArrangement` or `<layoutMargins>` on any `<stackView>` in storyboard XML — these are not valid in this project and cause "Failed to unarchive element named 'stackView'". Always use a wrapper `UIView` with explicit top/leading/trailing/bottom constraints.

**Storyboard XML rules:**
- `toolsVersion="23504"` and `plugIn version="23506"`
- Add `<freeformSimulatedSizeMetrics key="simulatedDestinationMetrics"/>` for bottom sheets
- `DSLabel` / `DSButton` as `customClass` with `customModule="CTDesignSystem"`
- ViewController `customModule` matches the Xcode target (e.g. `"ChoTot"`) — check sibling storyboards
- All outlets wired in `<connections>` at the ViewController scene level
- `storyboardIdentifier` must match the ViewController class name exactly
- Use `distribution="fillEqually"` on horizontal button StackViews — no explicit width constraints
- Body padding → wrapper `UIView` + constraints, NOT `layoutMarginsRelativeArrangement`
- XML comments: ASCII only — no Unicode / box-drawing characters

---

### Step 6 — Register in Xcode Project (project.pbxproj)

Add exactly **5 entries** to `ChoTot.xcodeproj/project.pbxproj`:

| Section | Entry |
|---|---|
| `PBXBuildFile` | `<UUID> /* <Name>.swift in Sources */` |
| `PBXBuildFile` | `<UUID> /* <Name>.storyboard in Resources */` |
| `PBXFileReference` | Swift file (`lastKnownFileType = sourcecode.swift`) |
| `PBXFileReference` | Storyboard file (`lastKnownFileType = file.storyboard`) |
| `PBXGroup` (target folder) | Both file refs listed under the correct group |
| Sources build phase | Swift build file UUID |
| Resources build phase | Storyboard build file UUID |

**UUID generation:**
```bash
uuidgen | tr -d '-' | cut -c1-24
```

**Finding the correct group:** Search `project.pbxproj` for a **sibling file** already in the same `MODULE_PATH` folder to locate the group UUID and insert near it.

---

## Design Token Mapping (Figma → CTDesignSystem)

| Figma | Swift |
|---|---|
| SemiBold 16px (header) | `DS.TypoToken.Header.Section(color:)` |
| SemiBold 20px (page title) | `DS.TypoToken.Header.Page(color:)` |
| Regular 14px (body) | `DS.TypoToken.Body.Section(color:)` |
| Bold 16px (label) | `DS.TypoToken.Label.Page(color:)` |
| Button fill `#FFD400` | `DS.Button.primary(size:, themeType:)` |
| Button white/bordered | `DS.Button.secondary(size:, themeType:)` |
| `rgba(34,34,34)` | `theme.text.textPrimary.color` |
| `rgba(89,89,89)` | `theme.text.textSecondary.color` |
| `rgba(251,115,40)` (orange warning) | `theme.background.backgroundWarningLight.color` |
| Warning icon | `CTAssetSystemIcon.warningFill24px(tint:)` |
| Close icon | `CTAssetSystemIcon.closeOutline24px()` |
| 1px divider line | `UIView` with `height = 1` constraint |

---

## Completion Checklist

Before finishing, verify:

- [ ] ViewController IBOutlets match storyboard outlet connections exactly
- [ ] All `@IBAction` selectors match storyboard action connections
- [ ] `storyboardIdentifier` matches the ViewController class name
- [ ] SnapKit used for any programmatic constraints (no `NSLayoutConstraint`)
- [ ] Storyboard root section is a vertical UIStackView (not anchor-chained views)
- [ ] Header/body/footer are StackView children — not manually top/bottom chained
- [ ] Button rows use `distribution=fillEqually` StackView (not equal-width constraints)
- [ ] Body padding done via a wrapper `UIView` with explicit top/leading/trailing/bottom constraints — **NEVER** `layoutMarginsRelativeArrangement` or `<layoutMargins>` in XML
- [ ] No XML comments with non-ASCII characters inside the storyboard XML
- [ ] 5 pbxproj entries added (2 PBXBuildFile, 2 PBXFileReference, group + build phases)
- [ ] File header has correct `git config user.name` and current date from `mcp__time__get_current_time`
- [ ] `deinit { Logger.print("\(self) deallocated.") }` present
- [ ] `[weak self]` used in dismiss closures

---

## Common Issues and Solutions

### ❌ Issue: "Failed to unarchive element named 'stackView'" when opening storyboard in Xcode

**Root cause 1 — `layoutMarginsRelativeArrangement` + `<layoutMargins>` XML element:**
This attribute/element combination is **NOT valid** in this project's storyboard XML format. Zero existing storyboards in the project use it. Xcode fails to parse the `<stackView>` element and throws the unarchive error.

**Fix:** Never use `layoutMarginsRelativeArrangement="YES"` or `<layoutMargins key="layoutMargins" .../>` in generated storyboards.
Instead, wrap the content in a plain `UIView` with explicit `top/leading/trailing/bottom` constraints to achieve padding:
```xml
<view id="body-container">          <!-- UIView fills StackView width -->
    <subviews>
        <stackView id="body-stack"> <!-- pinned: top=24, leading=16, trailing=16, bottom=24 -->
            ...
        </stackView>
    </subviews>
    <constraints>
        <constraint firstItem="body-stack" firstAttribute="top"      secondItem="body-container" secondAttribute="top"      constant="24"/>
        <constraint firstItem="body-stack" firstAttribute="leading"  secondItem="body-container" secondAttribute="leading"  constant="16"/>
        <constraint firstItem="body-container" firstAttribute="trailing" secondItem="body-stack" secondAttribute="trailing" constant="16"/>
        <constraint firstItem="body-container" firstAttribute="bottom"   secondItem="body-stack" secondAttribute="bottom"   constant="24"/>
    </constraints>
</view>
```

**Root cause 2 — XML comments with non-ASCII characters:**
Comments like `<!-- ── Header ── -->` (using box-drawing chars U+2500) or any non-ASCII inside XML comments can cause storyboard parse failures.

**Fix:** Use only plain ASCII in XML comments, or remove comments entirely from generated storyboards.

---

### Issue: Figma node not found
**Cause:** Node ID uses `-` separator in URL but Figma API uses `:`.
**Solution:** The proxy auto-converts — pass the raw URL; `mcp__figma__get_design_context` handles it.

### Issue: Storyboard file is too large to write
**Cause:** Complex multi-section layout with many nested views.
**Solution:** Write the storyboard in sections — header StackView first, then body, then footer. Verify XML validity with a quick sanity check (matching open/close tags).

### Issue: pbxproj group UUID not found
**Cause:** The module folder doesn't have a sibling file in pbxproj yet.
**Solution:** Search for the parent folder's group instead (e.g. `Ver2/Pos` → search `Ver2`) and add a new subgroup.

### Issue: DSButton / DSLabel not found as customClass in storyboard
**Cause:** `customModule` set to wrong module name.
**Solution:** Use the module name from the `.xcodeproj` target (e.g. `ChoTot`, not `CTCorePayment`) — check sibling storyboards for the correct value.

---

## Example

```
FIGMA_URL: https://www.figma.com/design/GlkeqMpiIEcPpIAoHO6FKL/Revenue-Handoff-2026?node-id=2703-10882&m=dev
MODULE_PATH: ChoTot/Features/Job/VerticalizePos/Presentation/Ver2/Pos
COMPONENT_TYPE: bottom_sheet
```

**Expected output:**
1. `JBWarningMessageViewController.swift` — ViewController with DSBottomSheetLayout, IBOutlets, configureUI(), IBActions
2. `JBWarningMessage.storyboard` — UIStackView-based layout with DSLabel/DSButton custom classes, outlets wired
3. 5 pbxproj entries in `ChoTot.xcodeproj/project.pbxproj`
