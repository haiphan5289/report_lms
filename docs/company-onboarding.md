# Company Onboarding & Join Code — Feature Document

> **Jira:** — (no ticket key in branch name) | **Branch:** `feat/login` | **Generated:** 2026-07-29
>
> No Jira/Confluence data fetched. Built directly from code (read, not guessed) across `Sources/Presentation/Modules/SignUp/`, `Sources/Presentation/Modules/Profile/`, `Sources/Presentation/Modules/Login/`, `Sources/Presentation/Modules/RootView/`, `Sources/Data/Services/CompanyService.swift`, `Sources/Domain/Entities/Company.swift`, and `functions/scripts/`.

---

## PRD Summary

> What the feature does and why it exists.

- **Goal:** Let a new user either create a brand-new company (becoming its `owner`) or join an existing one via a 6-character join code (becoming a `member`). Every company has a shareable join code that any of its members can view later from their Profile screen.
- **User story:** As a new inspector, I want to sign up and either start a new company or join my team's existing one using a code my admin gave me — and later, from my Profile, look up that code again to invite more colleagues.
- **Acceptance criteria:** *Not available — no Jira ticket to extract from.*

---

## Business Rules

| Rule | Description |
|------|-------------|
| Join code format | 6 characters, alphabet `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (excludes ambiguous `0/O/1/I`) — see [`CompanyService.generateUniqueJoinCode()`](../report_lms/Sources/Data/Services/CompanyService.swift) |
| Company creation is atomic | `createCompany()` writes the `companies/{id}` doc, `joinCodes/{code}` doc, and the owner's `users/{uid}` profile in a single Firestore batch — either all three land or none do, preventing an orphaned company with no owner profile |
| Join code doubles as a uniqueness check | `joinCodes/{code}` is a separate collection keyed by the code itself (`document(code)`), rather than querying `companies` by a `joinCode` field |
| Security: only members of a company can read its doc | `firestore.rules`: `allow read: if isSignedIn() && (!hasProfile() \|\| myCompanyId() == companyId)` — a signed-in user mid-onboarding (`!hasProfile()`) can read any company (needed to resolve a join code before they have a profile); afterwards, only their own company |
| Sign-up rollback on mid-flow failure | If `createCompanyUseCase`/`joinCompanyUseCase` throws after `signUpUseCase` already created the Firebase Auth account, `rollbackSignUpUseCase.execute()` deletes that just-created account so the email is free to retry |
| Root navigation is driven by `isLoggedIn`, not by screen dismissal | [`RootView.swift`](../report_lms/Sources/Presentation/Modules/RootView/RootView.swift) swaps its entire root (`LoginView` ↔ `LMSHomeView`) the instant `UserManager.isLoggedIn` flips — this has direct consequences for SignUp flows, see Bug #1 below |
| `companyId` must be loaded before company-scoped UI can work | `UserManager.companyId` is only set via `setCompany(_:)`, called from `LoginViewModel.loadCompanyScopedData` (explicit login), `LoginViewModel.restoreSessionIfNeeded` (app relaunch), or the SignUp ViewModels — any screen that reads it must tolerate it starting `nil` |

---

## Architecture Overview

### Key Components

| Layer | File | Role |
|-------|------|------|
| Presentation | [`SignUpChoiceView.swift`](../report_lms/Sources/Presentation/Modules/SignUp/Views/SignUpChoiceView.swift) | Entry screen — "Create a new company" vs "Join with a code", pushed from `LoginView` |
| Presentation | [`CreateCompanyView.swift`](../report_lms/Sources/Presentation/Modules/SignUp/Views/CreateCompanyView.swift) + [`CreateCompanyViewModel.swift`](../report_lms/Sources/Presentation/Modules/SignUp/ViewModels/CreateCompanyViewModel.swift) | Sign-up form → creates company → success screen showing the generated join code → `finishOnboarding()` on dismiss |
| Presentation | [`JoinCompanyView.swift`](../report_lms/Sources/Presentation/Modules/SignUp/Views/JoinCompanyView.swift) + [`JoinCompanyViewModel.swift`](../report_lms/Sources/Presentation/Modules/SignUp/ViewModels/JoinCompanyViewModel.swift) | Sign-up form + join code field → resolves code → joins as `member` |
| Presentation | [`ProfileView.swift`](../report_lms/Sources/Presentation/Modules/Profile/ProfileView.swift) + [`ProfileViewModel.swift`](../report_lms/Sources/Presentation/Modules/Profile/ProfileViewModel.swift) | Displays the signed-in user's own company join code (`companyCodeSection`), with copy-to-clipboard |
| Presentation | [`LoginViewModel.swift`](../report_lms/Sources/Presentation/Modules/Login/ViewModels/LoginViewModel.swift) | `login()` / `biometricLogin()` (explicit sign-in) and `restoreSessionIfNeeded()` (app relaunch) both funnel into `loadCompanyScopedData(userId:)`, which fetches the `UserProfile` and calls `userManager.setCompany(...)` |
| Presentation | [`RootView.swift`](../report_lms/Sources/Presentation/Modules/RootView/RootView.swift) | App root — swaps `LoginView` ↔ `LMSHomeView` on `userManager.isLoggedIn`; `.task` calls `restoreSessionIfNeeded()` once per launch |
| Presentation | [`UserManager.swift`](../report_lms/Sources/Presentation/Modules/UserManager/UserManager.swift) | `ObservableObject` holding `isLoggedIn`/`currentUser`/`companyId`; `init()` restores `isLoggedIn` from Keychain synchronously but **not** `companyId` (see Bug #2) |
| Domain | [`Company.swift`](../report_lms/Sources/Domain/Entities/Company.swift) | Entity + `fromFirestore(_:id:)` — manual field-by-field parsing (see Bug #3), dual ISO8601 parsing (see Bug #4) |
| Domain | [`UserProfile.swift`](../report_lms/Sources/Domain/Entities/UserProfile.swift) | `id` / `companyId` / `role` (`.owner`/`.member`) / `displayName` |
| Domain | [`CreateCompanyUseCase.swift`](../report_lms/Sources/Domain/UseCases/CreateCompanyUseCase.swift), [`JoinCompanyUseCase.swift`](../report_lms/Sources/Domain/UseCases/JoinCompanyUseCase.swift), [`FetchUserProfileUseCase.swift`](../report_lms/Sources/Domain/UseCases/FetchUserProfileUseCase.swift), [`FetchCompanyUseCase.swift`](../report_lms/Sources/Domain/UseCases/FetchCompanyUseCase.swift) | Thin pass-throughs to `CompanyRepositoryType` |
| Data | [`CompanyService.swift`](../report_lms/Sources/Data/Services/CompanyService.swift) | Firestore-backed `CompanyServiceType` — `createCompany`, `joinCompany`, `fetchUserProfile`, `fetchCompany`, `generateUniqueJoinCode` |
| Data | [`CompanyRepository.swift`](../report_lms/Sources/Data/Repositories/CompanyRepository.swift) | Pass-through to `CompanyServiceType` |
| Data | [`AsyncTimeout.swift`](../report_lms/Sources/Common/Helpers/AsyncTimeout.swift) | `withTimeout(seconds:operation:)` — races any async call against a timer so a hang surfaces as a clear error |
| Backend (one-off scripts) | [`functions/scripts/migrate-add-default-company.js`](../functions/scripts/migrate-add-default-company.js), [`fix-company-name.js`](../functions/scripts/fix-company-name.js) | Node.js admin scripts — backfilled a "default company" (e.g. "IPS LMS") onto pre-existing accounts before this onboarding feature existed. **Writes `createdAt` via JS `Date.toISOString()`, which always includes milliseconds** — see Bug #4 |

### Data Flow — Create Company

```
SignUpChoiceView
  → CreateCompanyView (form: company name, display name, email, password)
    → CreateCompanyViewModel.createCompany()
        1. signUpUseCase.execute()               — creates Firebase Auth account, returns UserSession
        2. createCompanyUseCase.execute()        — CompanyService.createCompany() batch-writes
                                                     companies/{id} + joinCodes/{code} + users/{ownerId}
        3. userManager.setCompany(company.id)     — companyId available immediately (no root swap yet)
        4. storageService.loadCache(companyId:)   — preload inspection cache
        5. pendingSession = session; isSuccess = true
             ⤷ success screen renders, shows createdJoinCode
    → user taps "Bắt đầu"
        → CreateCompanyViewModel.finishOnboarding()
            → userManager.login(user: pendingSession)   — NOW flips isLoggedIn
                → RootView swaps root to LMSHomeView
```

> **Why `login()` is deferred to `finishOnboarding()`, not called in step 1-5:** see Bug #1.

### Data Flow — Join Company

```
SignUpChoiceView → JoinCompanyView (form: join code, display name, email, password)
  → JoinCompanyViewModel.joinCompany()
      1. signUpUseCase.execute()
      2. joinCompanyUseCase.execute()   — CompanyService.joinCompany() resolves joinCodes/{code} → companyId,
                                           writes users/{uid} profile as .member
      3. userManager.login(user: session)   — flips isLoggedIn immediately (no success screen to show first)
      4. userManager.setCompany(company.id)
      5. storageService.loadCache(companyId:)
      6. isSuccess = true   — currently unread by JoinCompanyView; RootView has already swapped by now
```

> `JoinCompanyViewModel.isSuccess` is dead state today (no UI reads it) — harmless only because `RootView`'s swap on `isLoggedIn` makes it moot. Flagged as a follow-up, not fixed in this pass (see Known Follow-Ups).

### Data Flow — Profile "Mã công ty" Display

```
App launch (Keychain token found) → RootView.task → LoginViewModel.restoreSessionIfNeeded()
  → loginUseCase.refreshSession() → loadCompanyScopedData(userId:) → userManager.setCompany(companyId)
                                                                          │
User navigates to ProfileView (may happen before OR after the above completes)
  → ProfileViewModel.init() → observeCompanyId()
      subscribes to userManager.$companyId (Combine) — fires immediately with current value,
      AND fires again later if companyId arrives after this screen is already open
  → loadCompanyJoinCode(companyId:)
      → withTimeout(10s) { fetchCompanyUseCase.execute(companyId:) }
          → CompanyService.fetchCompany(id:) → getDocument() → Company.fromFirestore(data, id:)
  → companyJoinCode published → companyCodeSection renders code + copy button
```

---

## Bug History (this session)

Four independent, compounding bugs — found in sequence, each masking the next until fixed.

| # | Bug | Root Cause | Fix |
|---|---|---|---|
| 1 | Success screen showing the new join code could never actually render | `createCompany()` called `userManager.login(user:)` (flips `isLoggedIn`) *before* setting `isSuccess`/`createdJoinCode`. `RootView` swaps its entire root the instant `isLoggedIn` changes, tearing down the still-mounted `CreateCompanyView` before the success UI ever painted. | Deferred the `login()` call into a new `finishOnboarding()`, invoked only when the user taps "Bắt đầu" on the success screen. [`CreateCompanyViewModel.swift:76-80`](../report_lms/Sources/Presentation/Modules/SignUp/ViewModels/CreateCompanyViewModel.swift#L76-L80) |
| 2 | `companyId` stayed `nil` for an entire session after an app relaunch (not a fresh login) | `UserManager.init()` restores `isLoggedIn` straight from a Keychain token but never re-fetches the `UserProfile` — that only happened inside `LoginViewModel.login()`, which doesn't run on a relaunch. | Added `LoginViewModel.restoreSessionIfNeeded()`, called once from `RootView.task`: no-ops unless `isLoggedIn && companyId == nil`, otherwise re-derives the session via `loginUseCase.refreshSession()` and re-runs the same `loadCompanyScopedData` used by a normal login. [`LoginViewModel.swift:79-105`](../report_lms/Sources/Presentation/Modules/Login/ViewModels/LoginViewModel.swift#L79-L105), [`RootView.swift`](../report_lms/Sources/Presentation/Modules/RootView/RootView.swift) |
| 3 | Race: `ProfileView` opened before `companyId` finished loading would give up permanently | `ProfileViewModel.loadCompanyJoinCode()` originally checked `userManager.companyId` exactly once (`guard let ... else { return }`), with no retry if it arrived a moment later. | Replaced the one-shot check with a Combine subscription to `userManager.$companyId` (`observeCompanyId()`) — fires with the current value immediately, and again whenever it changes. [`ProfileViewModel.swift:78-86`](../report_lms/Sources/Presentation/Modules/Profile/ProfileViewModel.swift#L78-L86) |
| 4 | `Company.fromFirestore` silently threw `invalidField("createdAt")` for companies backfilled by the migration script | Two different `createdAt` string formats exist in Firestore: app-created companies (`JSONEncoder` + `.iso8601`, no milliseconds) vs. migration-script companies (JS `Date.toISOString()`, **always** includes milliseconds, e.g. `"2026-07-29T07:11:44.275Z"`). `ISO8601DateFormatter()`'s default options only parse the no-milliseconds form. | `Company.parseISO8601(_:)` tries `.withFractionalSeconds` first, then falls back to the default format. [`Company.swift:47-58`](../report_lms/Sources/Domain/Entities/Company.swift#L47-L58) |

**Also hardened while investigating Bug #4** (not itself the root cause, but a real latent crash risk): `Company.fromFirestore` originally round-tripped Firestore's `[String: Any]` through `JSONSerialization.data(withJSONObject:)`, which raises an **uncaught Objective-C exception** (not a catchable Swift `Error`) for any value that isn't a plain JSON type (e.g. a native Firestore `Timestamp`/`GeoPoint`). Rewritten as field-by-field `as?` casts with clean thrown errors instead. [`Company.swift:28-46`](../report_lms/Sources/Domain/Entities/Company.swift#L28-L46)

### Debugging note: OSLog `.debug()` is not reliable for this kind of investigation

Several rounds of this investigation added `Logger(...).debug(...)` tracing that never showed up in what the user was viewing, even though the code was executing (confirmed once `print()` was added instead). `.debug`-level unified-logging messages are not guaranteed to be captured/displayed the same way `.error()`/`.fault()` are, especially via a detached Console.app view. **For "why did this async call apparently never resolve" investigations, reach for `print()` first** (always visible live in Xcode's own console when running via Cmd+R) — reserve `Logger` for lower-volume, higher-level state transitions once the actual bug is understood.

---

## Known Follow-Ups (not fixed this session)

- `JoinCompanyViewModel.isSuccess` is unread by any View — either wire up a real use for it or remove it.
- `LMSButton` (`Sources/Common/Components/Buttons/LMSButton.swift`) uses `.buttonStyle(.plain)` with no built-in press feedback — every consumer that wants tap-scale currently has to hand-roll a `simultaneousGesture` wrapper (see `CreateCompanyView`/`JoinCompanyView`'s `ctaButton`). Worth fixing once, in the shared component, if this pattern keeps recurring.
- No automated test coverage added for the four bugs above — all verification this session was manual (Xcode console + Firestore console), tracked in this doc instead of a regression test.

---

## File Structure

```
Sources/Presentation/Modules/SignUp/
├── Views/
│   ├── SignUpChoiceView.swift
│   ├── CreateCompanyView.swift
│   └── JoinCompanyView.swift
└── ViewModels/
    ├── CreateCompanyViewModel.swift
    └── JoinCompanyViewModel.swift

Sources/Presentation/Modules/Profile/
├── ProfileView.swift
└── ProfileViewModel.swift

Sources/Presentation/Modules/Login/ViewModels/LoginViewModel.swift
Sources/Presentation/Modules/RootView/RootView.swift
Sources/Presentation/Modules/UserManager/UserManager.swift

Sources/Domain/
├── Entities/Company.swift
├── Entities/UserProfile.swift
├── Repositories/CompanyRepositoryType.swift
└── UseCases/
    ├── CreateCompanyUseCase.swift
    ├── JoinCompanyUseCase.swift
    ├── FetchUserProfileUseCase.swift
    └── FetchCompanyUseCase.swift

Sources/Data/
├── Services/CompanyService.swift
├── Services/CompanyServiceType.swift
└── Repositories/CompanyRepository.swift

Sources/Common/Helpers/AsyncTimeout.swift
Sources/Common/Extensions/View+Extensions.swift   (staggeredEntrance, Binding<CGFloat>.triggerShake)

functions/scripts/
├── migrate-add-default-company.js
└── fix-company-name.js

firestore.rules   (companies/{companyId}, joinCodes/{code}, users/{userId} rules)
```
