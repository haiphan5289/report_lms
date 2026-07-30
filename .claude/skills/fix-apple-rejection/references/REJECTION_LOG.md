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

---

## Rejection Round 3 (2026-07-30) — report_lms (IPS LMS)

> Note: by this round the project had pivoted from the TicTacToe demo to **report_lms**, a QA inspection app for garment factories (see top-level `README.md`). This log continues to track real App Store rejections regardless of which app is currently in this repo.

### Guideline 2.3.8 — App Name Mismatch (Marketplace vs. Device)

**Apple's message:**
> The app name displayed on app marketplaces and the app name displayed on the device do not sufficiently match... Marketplace app name: report_lms. Name displayed on the device: IPS LMS.

**Root cause:** `INFOPLIST_KEY_CFBundleDisplayName` in `project.pbxproj` is `"IPS LMS"` (the real product branding, also shown as the login screen title), while the App Store Connect listing name was left as `report_lms` (the internal/repo name).

**Fix:** No code change. Update the App Store Connect listing name (App Information → Name) to `IPS LMS` (or a close variant) to match the on-device name — decided as the correct direction since `IPS LMS` is the actual product brand shown in-app.

**Files checked:** `report_lms.xcodeproj/project.pbxproj` (`INFOPLIST_KEY_CFBundleDisplayName`, lines ~343/375).

---

### Guideline 3.1.1 — Business/Organization Account Registration

**Apple's message:**
> The app includes an account registration feature for businesses and organizations, which is considered access to external mechanisms for purchases or subscriptions... Remove the account registration features for business and organizations.

**Root cause:** Commit `ca601a3` ("[CustomerSuccess] add login register") added a self-service "Create Company" / "Join Company" onboarding flow reachable from a "Đăng ký" (Sign Up) link on `LoginView`, letting any user register a new business (company) account or join one via invite code — this reads to Apple as external business-account provisioning.

**Fix:** Removed the entire reachable registration flow and all code that became dead as a result:
- Removed `signUpLink` NavigationLink from `LoginView.swift` (the only entry point).
- Deleted `SignUp` module: `SignUpChoiceView`, `CreateCompanyView`, `JoinCompanyView`, `CreateCompanyViewModel`, `JoinCompanyViewModel`.
- Deleted use cases: `SignUpUseCase`, `RollbackSignUpUseCase`, `CreateCompanyUseCase`, `JoinCompanyUseCase`.
- Removed their DI registrations from `Container.swift`.
- Stripped now-unused `signUp`/`deleteCurrentUser` from `AuthRepositoryType`/`AuthRepository`/`AuthServiceType`/`AuthService`.
- Stripped now-unused `createCompany`/`joinCompany` from `CompanyRepositoryType`/`CompanyRepository`/`CompanyServiceType`/`CompanyService` (kept `fetchUserProfile`/`fetchCompany` — still used read-only by `ProfileViewModel`/`FetchUserProfileUseCase`/`FetchCompanyUseCase` to display existing company info).
- Removed now-orphaned `CompanyError.invalidJoinCode` / `.codeGenerationFailed` cases.

**Behavior after fix:** Login screen only supports logging into an existing, admin-provisioned account (email/password + biometric). There is no in-app path to create or join a company. Backend Cloud Functions scripts (`functions/scripts/*.js`) and Firestore rules/indexes for company onboarding were left untouched — they're admin/backend tooling, not reachable from the app UI Apple reviews.

**Verification note:** Confirmed via exhaustive `grep` sweep that no references to the removed symbols remain anywhere in `report_lms/`. A full `xcodebuild` was attempted but blocked by an unrelated, reproducible SPM package-cache issue in this environment (a stale `build` file under the `nanopb` Swift package checkout in DerivedData) — reproduced identically across two independent clean-DerivedData attempts, not caused by these edits. Recommend a normal build from Xcode.app before archiving to confirm.
