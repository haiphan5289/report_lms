---
title: Apple Rejection Log — TicTacToe App
source: docs/docs_fix_reject_apple.md
description: Real rejection cases from this project. Read before diagnosing a new rejection — check if the issue was already encountered and resolved.
---

# How to Use This Log

When a new rejection arrives:
1. Check if the guideline number appears in this log
2. If yes — use the recorded root cause and fix as a starting point
3. If no — follow the SKILL.md triage workflow and add the new case here after resolution

**Live source file:** [`references/docs_fix_reject_apple.md`](docs_fix_reject_apple.md)

---

## Rejection Round 1 — App Store Connect Metadata

### Invalid Characters in Description

**Trigger:** App Store Connect shows "This field contains one or more invalid characters."

**Rejected characters:**
| Character | Unicode | Name |
|---|---|---|
| `✦` | U+2726 | Black Four Pointed Star |
| `–` | U+2013 | En Dash |
| `×` | U+00D7 | Multiplication Sign |
| `•` | U+2022 | Bullet |

**Fix:** Replace all with plain ASCII (`*`, `-`, `x`, `*`).

**Prevention:** Paste into Notes app (plain text mode) first to strip hidden Unicode before copying into App Store Connect.

---

## Rejection Round 2 (2026-05-07)

### Guideline 2.1(a) — Placeholder Text in Description

**Apple's message:**
> The submission includes content that is not complete and final. Specifically, the description contains placeholder text.

**Root cause:** App Store Connect description still contained AI-generated instruction text:
```
Write a user-friendly summary of your app's features and benefits.
Highlight what makes your Tic-Tac-Toe app unique...
```

**Fix:** Replace with final accepted description (no code change):
```
Tic Tac Toe - Classic strategy game reimagined with a sleek, dark design and real-time online multiplayer.

* Play Online - Challenge players worldwide in real-time matches powered by Firebase. Create a game or join a friend's room with a simple code.

* 2 Player Local - Play against a friend on the same device, no account needed.

* Large Board - Enjoy a 15x15 board for a deeper, more strategic experience.

* Premium Dark UI - Smooth gameplay with a clean gold-and-dark design built for modern iPhones and iPads.

Simple to learn, hard to master. Download and challenge your friends today!
```

---

### Guideline 5.1.1(v) — Login Required for Offline Mode

**Apple's message:**
> The app requires users to register or log in to access features that are not account based. Specifically, the app requires users to register before accessing the two-player offline game mode.

**Root cause:** `RootView` gated ALL navigation behind `LoginView` when `isAuthenticated == false`, including the local 2-player game mode which requires no account.

**Files changed:**
- `tictactoe/Sources/Presentation/Modules/TicTacToe/RootView/RootView.swift`
- `tictactoe/ContentView.swift`

**Fix summary:**
- `RootView`: removed `isAuthenticated` gate → `ContentView` always shows after splash
- `ContentView`: added auth check only inside `navigateTo()` for `.online` and `.profile` modes
- `.local` mode skips the auth check entirely → goes directly to `TicTacToeView`

**Behavior after fix:**
| Tap | Before | After |
|---|---|---|
| "2 Nguoi Choi" (offline) | Login screen | Game starts directly |
| "Choi Online" | Login screen | Login screen (correct) |
| Login success | Sheet stayed open | Sheet dismisses, navigates to online game |
| Logout / Delete account | Stuck on Profile | Pops back to HomeView |

**App Store Connect reply used:**
```
--- Guideline 2.1(a) ---
We replaced all placeholder text in App Store Connect description
with final, accurate content.

--- Guideline 5.1.1(v) ---
Root cause: RootView gated ALL navigation behind authentication,
incorrectly blocking the 2-player offline game mode.

Fix: Auth check moved to individual navigation actions. "2 Nguoi Choi"
now launches directly without login. Only "Choi Online" and Profile
require authentication.

Testing:
1. Launch without signing in -- home screen appears immediately
2. Tap "2 Nguoi Choi" -- game board opens directly, no login
3. Tap "Choi Online" -- Sign In sheet appears as expected
```

---

## Additional Bugs Fixed During Rejection Resolution

### Google Sign-In: UI API on Background Thread

**Symptom:** `Main Thread Checker: UI API called on a background thread: -[UIViewController view]`

**Root cause:** `FirebaseAuthService.signInWithGoogle()` missing `@MainActor` — ran on cooperative background thread, calling UIKit APIs inside `GIDSignIn`.

**Fix:** Added `@MainActor` to `signInWithGoogle()` and `reauthenticateWithGoogle()` in `FirebaseAuthService.swift`. (`signInWithApple()` already had `@MainActor`.)

### Login Sheet Not Dismissing After Success

**Symptom:** Login sheet stays open after successful login.

**Root cause:** Nothing set `showingLogin = false` when `authManager.isAuthenticated` became `true`.

**Fix:** Added `.onChange(of: authManager.isAuthenticated)` in `ContentView` — when `isAuthenticated` becomes `true`, `showingLogin = false`; when it becomes `false` (logout/delete), `navigationPath` is cleared.

### Auto-Navigation to Profile After Login

**Symptom:** After login, app navigated to Profile instead of intended destination.

**Root cause:** `pendingMode` could be overwritten — if Profile button was tapped after "Choi Online" (or accidentally during sheet presentation), `pendingMode` flipped from `.online` → `.profile`.

**Fix:** Once `showingLogin = true`, `pendingMode` is locked. Profile taps during active login sheet are ignored. Only `.online` sets a `pendingMode` for deep-link navigation.
