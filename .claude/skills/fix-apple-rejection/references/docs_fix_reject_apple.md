# Apple App Store Rejection — Fix Log

---

## Rejection Round 2 (2026-05-07)

### Guideline 2.1(a) — App Completeness: Placeholder Text in Description

**Apple's message:**
> The submission includes content that is not complete and final. Specifically, the description contains placeholder text.

**Root cause:**
The App Store Connect description field still contained the AI-generated instruction text instead of real content:
```
Write a user-friendly summary of your app's features and benefits.
Highlight what makes your Tic-Tac-Toe app unique...
Keep it concise, engaging, and avoid technical jargon.
```

**Fix (App Store Connect metadata — no code change):**
Replace the placeholder text with the final accepted description below (see "Final Accepted Description" section).

---

### Guideline 5.1.1(v) — Privacy: Login Required for Offline Mode

**Apple's message:**
> The app requires users to register or log in to access features that are not account based. Specifically, the app requires users to register before accessing the two-player offline game mode.

**Root cause:**
`RootView` gated ALL navigation behind `LoginView` when `authManager.isAuthenticated == false`, including the local 2-player game mode which needs no account.

**Fix (code changes):**

`RootView.swift` — Remove `isAuthenticated` gate, always show `ContentView`:
```swift
// BEFORE (rejected)
} else if authManager.isAuthenticated {
    ContentView().environmentObject(authManager)
} else {
    LoginView().environmentObject(authManager)  // blocked 2 Nguoi Choi
}

// AFTER (fixed)
} else {
    ContentView().environmentObject(authManager)  // always show home
}
```

`ContentView.swift` — Gate login only on `.online` and `.profile`:
```swift
func navigateTo(_ mode: GameMode) {
    if mode == .online || mode == .profile {
        guard authManager?.isAuthenticated == true else {
            if !showingLogin {
                pendingMode = mode == .online ? .online : nil
                showingLogin = true
            }
            return
        }
    }
    navigationPath.append(mode)  // .local goes here directly — no login required
}
```

**Behavior after fix:**
| Action | Before | After |
|---|---|---|
| Tap "2 Nguoi Choi" (offline) | Shows login screen | Goes directly to game |
| Tap "Choi Online" | Shows login screen | Shows login screen (correct) |
| After login → dismiss | Stuck or wrong screen | Auto-navigates to intended destination |
| Logout / Delete account | Stayed on Profile | Pops to HomeView |

**App Store Connect Reply Template:**
```
Dear App Review Team,

--- Guideline 2.1(a) ---
We have replaced all placeholder text in the App Store Connect description
with final, accurate content describing the app's features.

--- Guideline 5.1.1(v) ---
Root cause: RootView was gating ALL navigation behind authentication,
incorrectly blocking the local 2-player (offline) game mode.

Fix: We moved the authentication check from root level to individual
navigation actions. "2 Nguoi Choi" (2 Player offline) now launches
directly without login. Only "Choi Online" and Profile continue to
require authentication, as they are account-dependent features.

Testing Steps:
1. Launch the app without signing in -- home screen appears immediately
2. Tap "2 Nguoi Choi" -- game board opens directly, no login required
3. Tap "Choi Online" -- Sign In sheet appears as expected

Thank you,
Hai Phan
```

---

# Fix: App Store Connect - Invalid Characters in Description

## Problem

App Store Connect shows error:
> "This field contains one or more invalid characters."

when submitting the app description.

## Root Cause

The following characters are **not accepted** by App Store Connect:

| Character | Unicode | Name | Status |
|-----------|---------|------|--------|
| `✦` | U+2726 | Black Four Pointed Star | Rejected |
| `–` | U+2013 | En Dash | Rejected |
| `×` | U+00D7 | Multiplication Sign | Rejected |
| `•` | U+2022 | Bullet | Rejected (in some fields) |

## Fix

Replace all special/Unicode characters with plain ASCII equivalents:

| Replace | With |
|---------|------|
| `✦` | `*` |
| `–` | `-` |
| `×` | `x` |
| `•` | `*` |

## Final Accepted Description

```
Tic Tac Toe - Classic strategy game reimagined with a sleek, dark design and real-time online multiplayer.

* Play Online - Challenge players worldwide in real-time matches powered by Firebase. Create a game or join a friend's room with a simple code.

* 2 Player Local - Play against a friend on the same device, no account needed.

* Large Board - Enjoy a 15x15 board for a deeper, more strategic experience.

* Premium Dark UI - Smooth gameplay with a clean gold-and-dark design built for modern iPhones and iPads.

Simple to learn, hard to master. Download and challenge your friends today!
```

## Tips

- Always paste text into Notes app (plain text mode) first before copying into App Store Connect to strip hidden Unicode characters.
- Use only ASCII characters (A-Z, 0-9, basic punctuation) to be safe.
- If the error persists, paste one paragraph at a time to isolate the offending character.
