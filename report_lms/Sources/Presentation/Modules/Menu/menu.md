# Menu — Feature Document

> **Jira:** — | **Branch:** `feat/login` | **Generated:** 2026-07-08

> Jira/Confluence not fetched — no ticket key found in the current branch name (`feat/login`) and no `JIRA`/`CONFLUENCE` params were provided.
> ℹ️ This module is a single stateless SwiftUI view (no dedicated ViewModel) — the "Architecture Overview" below documents it together with its actual owner, [`LMSHomeView.swift`](../Home/LMSHomeView.swift), since that's where all of its behavior is actually wired up.

---

## PRD Summary

> What the feature does and why it exists.

- **Goal:** Provide a side-drawer navigation menu from the Home screen so the user can jump to Profile, Settings, Orders, Email History, or log out.
- **User story:** As a logged-in user, I want to open a menu from the home screen so that I can navigate to my profile, settings, orders, or email history, or sign out.
- **Acceptance criteria:**
  - Not available — add manually (no Jira ticket linked to this branch)

---

## Business Rules

> Key business constraints and logic, verified against [`MenuView.swift`](MenuView.swift) and its caller [`LMSHomeView.swift`](../Home/LMSHomeView.swift).

| Rule | Description |
|------|-------------|
| Stateless view, caller owns behavior | `MenuView` has no ViewModel and holds no navigation logic itself — it only renders 5 buttons and forwards taps through a single `onAction: (MenuAction) -> Void` closure ([`MenuView.swift:22-24`](MenuView.swift#L22-L24)). All actual routing lives in the call site. |
| Single call site | `MenuView` is instantiated in exactly one place in the codebase: [`LMSHomeView.swift:111`](../Home/LMSHomeView.swift#L111), as a 300pt-wide side drawer. |
| Menu visibility state | Presentation is driven by `LMSHomeViewModel.showMenu` (`@Published var showMenu = false`); opened via `showMenuAction()`, closed by tapping the dimmed overlay or by any menu action itself ([`LMSHomeViewModel.swift:15`](../Home/LMSHomeViewModel.swift#L15), [`LMSHomeViewModel.swift:37-38`](../Home/LMSHomeViewModel.swift#L37-L38)). |
| Action → route mapping | `.profile` → `navigateToProfile()` → pushes `"profile"`; `.settings` → `navigateToSettings()` → pushes `"settings"`; `.orders` → `navigateToOrders()` → pushes `"orders"`; `.sendEmailList` → closes the menu then pushes `"sendEmailList"` directly (not via a `navigateTo...()` method); `.logout` → closes the menu then calls the `onLogout()` closure passed into `LMSHomeView` ([`LMSHomeView.swift:111-136`](../Home/LMSHomeView.swift#L111-L136), [`LMSHomeViewModel.swift:53-65`](../Home/LMSHomeViewModel.swift#L53-L65)). |
| Route resolution | All string routes are resolved by a single `navigationDestination(for: String.self)` switch in `LMSHomeView` ([`LMSHomeView.swift:65-83`](../Home/LMSHomeView.swift#L65-L83)): `"profile"` → placeholder `Text("Profile")`, `"settings"` → `SettingsView()`, `"orders"` → `OrdersView()`, `"sendEmailList"` → `SendEmailListDestination()`. |
| Untranslated menu item | "Lịch sử Email" (Email History) is a hardcoded Vietnamese literal, unlike the other 4 items which call `localizationManager.localize(...)` ([`MenuView.swift:59`](MenuView.swift#L59) vs. lines 47/51/55/65). There is no `"menu.sendEmailList"` key defined in either language table in [`LocalizationManager.swift`](../../../Common/Helpers/LocalizationManager.swift) — this label will not translate when the app language is switched to English. |

---

## Architecture Overview

> Stateless SwiftUI view + callback closure — logic lives in the parent (`LMSHomeView` / `LMSHomeViewModel`), not in this module.

### Key Components

| Layer | File | Role |
|-------|------|------|
| Presentation | [`MenuView.swift`](MenuView.swift) | Renders the drawer: title, 4 nav items (Profile/Settings/Orders/Email History), 1 destructive Logout item. Fires `onAction(MenuAction)` on tap. |
| Presentation | [`MenuView.swift:12-18`](MenuView.swift#L12-L18) — `MenuAction` enum | `.profile`, `.settings`, `.orders`, `.sendEmailList`, `.logout` |
| Presentation (owner) | [`LMSHomeView.swift`](../Home/LMSHomeView.swift) | Presents `MenuView` as a side-drawer overlay; the `onAction` closure here contains all routing logic |
| Presentation (state) | [`LMSHomeViewModel.swift`](../Home/LMSHomeViewModel.swift) | Owns `showMenu`, `navigationPath`, and the `navigateToProfile()`/`navigateToSettings()`/`navigateToOrders()` methods |
| Destination (placeholder) | `Text("Profile")` inline in [`LMSHomeView.swift:74-75`](../Home/LMSHomeView.swift#L74-L75) | Profile screen is not yet implemented — plain text placeholder |
| Destination | `SettingsView()` — resolved by the same switch, referenced at [`LMSHomeView.swift:77`](../Home/LMSHomeView.swift#L77) | Settings screen |
| Destination | `OrdersView()` — [`LMSHomeView.swift:72`](../Home/LMSHomeView.swift#L72) | Orders list screen |
| Destination | `SendEmailListDestination()` — [`LMSHomeView.swift:79`](../Home/LMSHomeView.swift#L79) | Email delivery history screen |

### Data Flow

```
User taps hamburger icon (LMSHomeView.menuButton)
  → LMSHomeViewModel.showMenuAction() → showMenu = true
  → MenuView rendered as a 300pt side-drawer overlay in LMSHomeView

User taps a MenuView row
  → onAction(.profile / .settings / .orders / .sendEmailList / .logout)   (closure defined in LMSHomeView.swift:111-136)
    ├─ .profile      → LMSHomeViewModel.navigateToProfile()   → navigationPath.append("profile")
    ├─ .settings     → LMSHomeViewModel.navigateToSettings()  → navigationPath.append("settings")
    ├─ .orders       → LMSHomeViewModel.navigateToOrders()    → navigationPath.append("orders")
    ├─ .sendEmailList→ showMenu = false; navigationPath.append("sendEmailList")   (no dedicated navigateTo... method)
    └─ .logout       → showMenu = false; onLogout()            (bubbles up out of LMSHomeView entirely)
  → NavigationStack's navigationDestination(for: String.self) resolves the pushed route to a concrete view
```

---

## Key Files & Symbols

> Files under `Menu/` changed on this branch (git diff `main...HEAD`), plus the verified call site.

### Presentation
- [`MenuView.swift`](MenuView.swift) — the drawer view + `MenuAction` enum (only file in this module)

### Owner / call site (referenced, not in this diff)
- [`LMSHomeView.swift`](../Home/LMSHomeView.swift) — presents `MenuView`, owns the `onAction` routing closure and the `navigationDestination(for: String.self)` switch
- [`LMSHomeViewModel.swift`](../Home/LMSHomeViewModel.swift) — `showMenu`, `navigationPath`, `navigateToProfile()`/`navigateToSettings()`/`navigateToOrders()`

### Shared UI components used (verified to exist, not new in this diff)
- `LMSLabel`, `LMSButton` (variants used: `.ghost`, `.destructive`)

---

## API Contracts

> No API calls originate from this module — it is pure client-side navigation. `> No new API targets detected in this diff.`

---

## Edge Cases & Error Handling

> Verified against [`MenuView.swift`](MenuView.swift) and [`LMSHomeView.swift`](../Home/LMSHomeView.swift).

| Scenario | Expected Behavior | Handled? |
|----------|------------------|----------|
| User taps "Hồ sơ" (Profile) | Menu closes, navigates to `"profile"` route | ⚠️ Route resolves to a bare `Text("Profile")` placeholder, not a real Profile screen |
| User taps "Cài đặt" (Settings) | Menu closes, navigates to `SettingsView()` | ✅ |
| User taps "Đơn hàng" (Orders) | Menu closes, navigates to `OrdersView()` | ✅ |
| User taps "Lịch sử Email" (Email History) | Menu closes, navigates to `SendEmailListDestination()` | ✅ navigation works, ⚠️ but the label itself is hardcoded Vietnamese and won't localize to English |
| User taps "Đăng xuất" (Logout) | Menu closes, `onLogout()` fires | ✅ |
| User taps the dimmed background overlay | Menu closes without navigating | ✅ ([`LMSHomeView.swift:104-108`](../Home/LMSHomeView.swift#L104-L108)) |
| Rapid double-tap on a menu item | No explicit debounce/guard against firing `onAction` twice or navigating twice | ❌ Not handled — `navigationPath.append` twice in quick succession is not guarded against in this file |

---

## Test Coverage Notes

| Component | Test File | Coverage |
|-----------|-----------|----------|
| `MenuView` | — | ❌ Missing |
| `LMSHomeViewModel` navigation methods | — | ❌ Missing |

No test target exists in this repository at the time of writing.

**Suggested test cases:**
- [ ] Tapping each menu row invokes `onAction` with the correct `MenuAction` case
- [ ] `LMSHomeViewModel.navigateToProfile()` / `navigateToSettings()` / `navigateToOrders()` each set `showMenu = false` and append the correct route string
- [ ] `.sendEmailList` action closes the menu and appends `"sendEmailList"` even though it bypasses the `navigateTo...()` method pattern used by the other three
- [ ] `.logout` action closes the menu and invokes the injected `onLogout` closure exactly once

---

## Notes

> Additional context, open questions, or known limitations.

- No Jira ticket is linked to the current branch (`feat/login`); commit history touching this module (`[Revenue][CRE-] add feature botton sheet report`, `[Revenue][CRE-] add setting`, `add list order`) suggests menu items were added incrementally as their destination screens landed.
- The `"profile"` route resolves to a placeholder `Text("Profile")` rather than a real screen — confirm whether a Profile feature is planned or whether the menu item should be hidden/disabled until it exists.
- "Lịch sử Email" is not run through `localizationManager.localize(...)` and has no corresponding key in either language table — worth fixing for English-language users, and for consistency with the other four menu items which are all localized.
- `MenuAction` and its handling live entirely at the `LMSHomeView` call site rather than in this module — future menu items added here will need matching cases added in `LMSHomeView.swift`'s `onAction` closure and, if they navigate, in its `navigationDestination(for: String.self)` switch.

---

*Generated by `/ct-ai-document` on 2026-07-08*
