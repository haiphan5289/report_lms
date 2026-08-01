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

> **⚠️ Correction (2026-08-01):** the fix described above was never actually completed — see Round 4 below. The commit that shipped for this entry (`7359fb7`) only consolidated `CreateCompanyViewModel`/`JoinCompanyViewModel` into a single `SignUpViewModel` and trimmed the join-by-code path; it did **not** remove `signUpLink` from `LoginView.swift`, nor delete `SignUpUseCase`/`RollbackSignUpUseCase`/`CreateCompanyUseCase`/`SignUpView`/`SignUpViewModel`, nor strip `signUp`/`deleteCurrentUser`/`createCompany` from the Auth/Company stacks. The registration entry point stayed fully reachable, which is exactly why Apple's re-review on the same submission flagged 3.1.1 again. Lesson: don't trust this log's "Fix" section as proof the fix landed — verify against current code (`grep` for the named symbols) before treating a past entry as resolved.

---

## Rejection Round 4 (2026-08-01) — Re-review, same submission (abed2cb7)

### Guideline 3.1.1 — Business/Organization Account Registration (recurrence)

**Apple's message:** Same as Round 3 — "The issues we previously identified still need your attention... Remove the account registration features for business and organizations." (Submission `abed2cb7-abec-4cb0-916f-6d8227dd0589`, reviewed on iPad Air 11-inch M3, build 202608010900.)

**Root cause:** The Round 3 fix was incomplete (see correction note above) — `signUpLink` in `LoginView.swift` was still live, still navigating to `SignUpView` → `SignUpViewModel.signUp()`, which still created a Firebase Auth account **and** a new `companies/{id}` Firestore document in one step. This is precisely the "external business-account provisioning" Apple's guideline targets.

**Fix — this time actually removing the reachable flow:**
- `LoginView.swift`: deleted the `signUpLink` computed property and its call site in `actionSection`. Login screen now only has email/password + forgot-password + biometric — no path to any sign-up screen.
- Deleted files: `Presentation/Modules/SignUp/Views/SignUpView.swift`, `Presentation/Modules/SignUp/ViewModels/SignUpViewModel.swift`, `Domain/UseCases/SignUpUseCase.swift`, `Domain/UseCases/RollbackSignUpUseCase.swift`, `Domain/UseCases/CreateCompanyUseCase.swift` (and the now-empty `SignUp` module directories).
- `Container.swift`: removed DI registrations for `SignUpUseCase`, `RollbackSignUpUseCase`, `CreateCompanyUseCase`, `SignUpViewModel`.
- Stripped now-orphaned `signUp`/`deleteCurrentUser` from `AuthServiceType`/`AuthService`/`AuthRepositoryType`/`AuthRepository` (only consumer was the deleted `SignUpUseCase`/`RollbackSignUpUseCase`).
- Stripped now-orphaned `createCompany` from `CompanyServiceType`/`CompanyService`/`CompanyRepositoryType`/`CompanyRepository` (only consumer was the deleted `CreateCompanyUseCase`). Kept `fetchUserProfile` — still used read-only by `FetchUserProfileUseCase`/`ProfileViewModel`.
- Kept `UpdateDisplayNameUseCase` — unrelated, still used by `ProfileViewModel` and `FinalReportViewModel`/`PDFReportRequestBuilder` to read/set the inspector's display name, not part of company provisioning.
- No `project.pbxproj` edits needed — this project uses Xcode 16 `PBXFileSystemSynchronizedRootGroup`, so file deletions on disk are picked up automatically.

**Behavior after fix:** There is no in-app path to create a Firebase Auth account or a company document. Login only works against an existing, admin-provisioned account.

**Verification:** Exhaustive `grep` sweep for `SignUp*`, `CreateCompanyUseCase`, `signUpLink`, `createCompany`, `.signUp(`, `.deleteCurrentUser(` across `report_lms/Sources` and `report_lms.xcodeproj` — zero matches. Full `xcodebuild -project report_lms.xcodeproj -scheme report_lms -sdk iphonesimulator build` — **BUILD SUCCEEDED**.

> **Correction:** the "still used read-only by `ProfileViewModel`" claim in the "Fix" bullet above was also wrong — re-verified by grep before Round 5 below: `FetchUserProfileUseCase`/`CompanyRepository`/`CompanyService`/`UserProfile` were only ever consumed by `LoginViewModel`, never by `ProfileViewModel`. Harmless in Round 4 (both were kept either way), but another reminder to verify this log's claims against current code rather than trusting them.

---

## Rejection Round 5 (2026-07-28 review, addressed 2026-08-01) — Guideline 3.2

### Guideline 3.2 — Business (public distribution vs. specific-business app)

**Apple's message:**
> We found in our review that the app is intended to be used by a specific business or organization, including partners, clients, or employees, but you've selected public distribution on the App Store... If the app is intended for use by a specific business or organization, review the other distribution options available for apps designed for specific businesses or organizations... Learn more about custom app distribution using Apple Business Manager... Learn more about unlisted app distribution.
(Submission `dd698a28-2b00-4598-bcbf-2ca3236b2d2c`, reviewed July 28, 2026 on iPhone 17 Pro Max, build 202607282100.)

**Root cause:** At review time, the app had no self-service way for a new business to start using it — every account was pre-provisioned by an admin into one specific `companies/{id}` tenant (see Round 3/4 above), and the app's entire feature set (QA inspection workflow, defect reporting, PDF reports to clients) is scoped per-company. That combination — professional/B2B content plus zero public entry point — is exactly what Apple's Guideline 3.2 flags: it reads as an internal tool for a fixed set of known clients, not a generally-available product, yet it was distributed on the public App Store.

**Options considered:**
1. Switch distribution to Unlisted App or Custom App (Apple Business Manager) — zero code change, directly matches Apple's own suggested remedy.
2. Re-add a public "create a new company" flow (multi-tenant SaaS self-signup, Slack/Asana-style) — rejected outright: this is functionally the same self-service business-account creation Apple already rejected once under **Guideline 3.1.1** (Round 3/4 above); re-adding it would very likely trigger 3.1.1 again.
3. Remove the "company" concept entirely — pivot every account to a standalone personal user, no organization/tenant layer at all.

The user chose option 3 after confirming (a) Firestore only holds test/demo data, so there's no production migration risk, and (b) option 2 is a confirmed dead end from real rejection history, not just a theoretical one.

**Fix — replace company tenancy with per-user ownership:**
- `Inspection`/`InspectionModel`: removed `companyId`/`companyName` fields entirely. `inspectorId` (pre-existing, previously always `nil`) is now the real ownership field, set to the signed-in user's Firebase Auth uid on creation.
- `FirestoreService.fetchInspections`, `FirestoreRepository`, `DatabaseRepositoryType`, `SyncInspectionsUseCase`, `InspectionStorageServiceType.loadCache`/`FirestoreInspectionStorageService.loadCache`: renamed `companyId` param → `inspectorId`, query filter changed from `.whereField("companyId", ...)` to `.whereField("inspectorId", ...)`.
- Deleted the whole company/profile stack: `UserProfile`, `CompanyRepositoryType`/`CompanyRepository`, `CompanyServiceType`/`CompanyService`, `FetchUserProfileUseCase` — verified by grep to be consumed only by `LoginViewModel`, nothing else.
- `UserManager`: removed `companyId`/`setCompany`. `LoginViewModel`: removed the profile-fetch step entirely, now calls `storageService.loadCache(inspectorId:)` directly after login; `restoreSessionIfNeeded` guards on `storageService.isCacheLoaded` instead of a company id.
- `CreateInspectionViewModel` and its two construction sites (`CreateInspectionView.swift`, `LMSHomeView.swift`) now resolve `UserManager.currentUser?.id` instead of `UserManager.companyId`.
- `firestore.rules`: replaced the `users/{uid}` + `companies/{id}` + `myCompanyId()` scheme with `isOwner(inspectorId)` checks directly on `inspections`, its `errorItems` subcollection, and `report_delivery_queue`. No rule needed for account creation (`Auth.auth().createUser` is a pure Auth call, no Firestore write).
- `firestore.indexes.json`: composite index field `companyId` → `inspectorId`.
- `functions/src/index.ts`: dropped the `companyName` placeholder (`%c`) from the report-delivery email template — this was actually a **latent bug**, not a regression: `CreateInspectionViewModel` always wrote `companyName: ""` on real (non-preview) inspections, so every past report email already rendered with a blank company name.
- Re-added personal sign-up (this is why it does **not** reintroduce 3.1.1 — no organization is created or joined): restored `signUp` on the `AuthServiceType`/`AuthService`/`AuthRepositoryType`/`AuthRepository` stack, recreated `SignUpUseCase`, `SignUpViewModel` (name/email/password only — no company step, so no rollback use case needed either), `SignUpView`, registered both in `Container.swift`, and re-added the `signUpLink` on `LoginView.swift`.
- UI cleanup: removed all `companyName` display rows/mock data across `InspectionCardView`, `InspectionDetailBottomSheet`, `OrderDetailBottomSheet`, `OrdersView`/`OrdersViewModel`, `InformationPurchaseView`/`ViewModel`, `ReportLMSHomeView`, `ProgressView`, `PlanLMSHomeView`, `InspectionStore`.
- Left untouched (pre-existing, unrelated dead code, only minimally patched to keep compiling against the new `Inspection` signature): `CreateInspectionUseCase`/`InspectionRepository`/`InspectionService`/`InspectionStore` mock-persistence path (real saves go through `FirestoreInspectionStorageService`, never through these). Also untouched: `functions/scripts/migrate-add-default-company.js`/`fix-company-name.js` (historical one-off scripts, not run by the app).

**Behavior after fix:** Every account is a standalone individual. Signing up creates only a personal Firebase Auth account; inspections are private to the inspector who created them; there is no shared "company" concept anywhere in the app or its data model.

**Verification:** Exhaustive `grep -rn "companyId\|companyName\|CompanyRepository\|CompanyService\|UserProfile\|myCompanyId"` over `report_lms/Sources`, `firestore.rules`, `firestore.indexes.json` — zero matches (excluding stale references in `.md` docs, left as-is). `xcodebuild -project report_lms.xcodeproj -scheme report_lms -sdk iphonesimulator build` — **BUILD SUCCEEDED**. `npx tsc --noEmit` in `functions/` — passed with no errors.
