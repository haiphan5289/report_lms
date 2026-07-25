---
name: fix-apple-rejection
description: Diagnose and fix Apple App Store rejection reasons for iOS apps. Use when your app submission is rejected — provide the rejection guideline number and description, and this skill produces a root-cause analysis, minimal code/config fixes, and a draft App Store Connect reply. Covers crashes, privacy, metadata, IAP, permissions, design, and entitlement issues.
model: sonnet
effort: high
---

# Fix Apple App Store Rejection

> **Anti-Hallucination:** Verify every symbol, path, plist key, and entitlement against the actual project before generating a fix. See [ct-anti-hallucination](.claude/skills/ct-anti-hallucination/SKILL.md).

> **Project Reference:** Always read [`README.md`](../../README.md) before diagnosing. This is a TicTacToe Firebase app — architecture is SwiftUI + Clean Architecture, Firebase RTDB for real-time sync, LMS Design System. Rejection fixes must preserve these constraints.

> **Rejection History:** ALWAYS read [`references/REJECTION_LOG.md`](references/REJECTION_LOG.md) FIRST before starting triage. It contains every real rejection this app has received, the verified root causes, the exact code fixes applied, and the App Store Connect replies that were accepted. Use it to avoid re-diagnosing issues already solved, and as a pattern library for similar new rejections.

## Overview

This skill provides a **structured rejection triage workflow** for App Store rejections. It identifies the root cause from the rejection guideline, scans only the relevant code and config, applies the minimal fix, and generates an App Store Connect reply template.

## When to Use This Skill

**Use this skill when:**
- Your app submission is rejected by Apple Review
- You receive a rejection email with a guideline number (e.g. `2.1`, `5.1.1`)
- App was previously approved but rejected on a re-submission
- You want to pre-flight a submission to avoid common rejections

## Input Format

```
GUIDELINE: [e.g. 2.1, 5.1.1, 4.2, 3.1.1]
REJECTION_DESCRIPTION: [Paste Apple's rejection message verbatim]
BUILD: [Build number or version, if known]
SCREENSHOTS: [Path to rejection screenshot(s) from Resolution Center, if any]
```

---

## Rejection Triage Workflow

### Step 0 — Check Rejection History First

Read [`references/REJECTION_LOG.md`](references/REJECTION_LOG.md) and check if the incoming guideline number was already encountered.

- **Match found** → use the recorded root cause as the starting hypothesis; verify it still applies to the current code, then apply or adapt the fix
- **No match** → proceed with Step 1 fresh triage; after resolving, append the new case to the log

### Step 1 — Identify Rejection Category

Map the guideline number to a category:

| Guideline | Category | Common Root Cause |
|---|---|---|
| **2.1** | Crashes & Bugs | App crashes on launch, broken flows, placeholder content |
| **2.3** | Accurate Metadata | Screenshot mismatch, keyword stuffing, wrong category |
| **2.5.4** | Hardware Compatibility | App claims non-existent hardware features |
| **3.1.1** | In-App Purchase | Bypassing IAP, linking to external payment |
| **3.2.1** | Other Business Models | Unapproved monetization |
| **4.0** | Design Copycats | App too similar to Apple's built-in apps |
| **4.2** | Minimum Functionality | App is too simple, wrapper around a website |
| **4.8** | Sign In with Apple | Offers third-party login but not Sign In with Apple |
| **5.1.1** | Data Collection & Storage | No privacy policy, or collecting data not declared |
| **5.1.2** | Data Use & Sharing | Tracking without consent, sharing PII without disclosure |
| **5.2.1** | Intellectual Property | Copyright/trademark violation |
| **5.5** | Developer Code of Conduct | Misleading description, fake reviews |

---

### Step 2 — Scope the Investigation (3-4 Files Max)

Only read files directly relevant to the rejection. Never explore broadly.

**For 2.1 Crashes:** Read crash log → identify file:line → read that ViewController/ViewModel only  
**For 5.1.x Privacy:** Read `Info.plist`, `PrivacyInfo.xcprivacy`, `AppDelegate`  
**For 3.1.1 IAP:** Read purchase flow ViewController + StoreKit manager  
**For 2.3 Metadata:** Check `Info.plist`, App Store Connect screenshots folder  
**For 4.8 Sign In with Apple:** Read authentication ViewController + capability entitlements  

---

### Step 3 — Root Cause Analysis

State the root cause in one sentence before proposing any fix.

**For each category, ask:**

**Crashes (2.1):**
- Does the crash reproduce on a clean install (no previous user data)?
- Is there a forced unwrap (`!`) near the crash location?
- Is a background thread updating UI? Check `DispatchQueue.main.async` wrapping
- Is a required capability missing from the entitlements (e.g. Push Notifications, iCloud)?
- Is a third-party SDK crashing on first launch (analytics, ads)?

**Privacy (5.1.1 / 5.1.2):**
- Is `NSPrivacyUsageDescription` (or equivalent plist key) present for every used API?
- Does `PrivacyInfo.xcprivacy` declare all accessed `NSPrivacyAccessedAPITypes`?
- Is there a privacy policy URL in App Store Connect?
- Does the app collect data not declared in the App Privacy section?

**Metadata (2.3):**
- Do screenshots show the actual app on a real device (not simulator)?
- Does the app name / subtitle match exactly what's in Info.plist `CFBundleDisplayName`?
- Are all screenshots the required resolutions (6.9", 6.5", 5.5" for iPhone)?
- Does the description contain disallowed phrases ("top", "#1", competitor names)?

**IAP (3.1.1):**
- Does any button or link direct users to a payment page outside the App Store?
- Is `SKPaymentQueue` used for all digital content purchases?
- Do physical goods/services correctly bypass StoreKit?

**Sign In with Apple (4.8):**
- Does the app offer Google, Facebook, or Twitter login without offering Sign In with Apple as an equal option?

---

### Step 4 — Apply Minimal Fix

Only fix the identified root cause. Never refactor unrelated code.

---

## Fix Recipes by Guideline

---

### 2.1 — Crash on Launch

**Diagnosis:** Crash log shows `EXC_BAD_ACCESS` or `fatal error: unexpectedly found nil`

**Fix pattern:**
```swift
// Bad: force unwrap on optional that's nil before view is ready
let user = UserManager.shared.currentUser!

// Good: guard + meaningful error handling
guard let user = UserManager.shared.currentUser else {
    showLoginScreen()
    return
}
```

**Firebase RTDB specific:** Ensure listener is attached after `Auth.auth().currentUser` is non-nil:
```swift
// Bad: attaching listener before auth completes
override func viewDidLoad() {
    super.viewDidLoad()
    listenToGameState() // currentUser may be nil here
}

// Good: wait for auth state
Auth.auth().addStateDidChangeListener { [weak self] _, user in
    guard user != nil else { return }
    self?.listenToGameState()
}
```

---

### 2.3 — Inaccurate Metadata

**Screenshots checklist:**
- [ ] Generated on a physical device or Simulator in Release mode
- [ ] Show actual gameplay / core feature (not onboarding/splash)
- [ ] No device frame overlapping content in unexpected ways
- [ ] Required sizes provided: 6.9" (1320×2868 @3x), 6.5" (1284×2778 @3x), 5.5" (1242×2208 @3x)

**App name:** Must match `CFBundleDisplayName` in `Info.plist`:
```xml
<key>CFBundleDisplayName</key>
<string>My Exact App Name</string>
```

---

### 5.1.1 — Privacy Policy / Data Collection

**Step 1:** Add all required `NSUsageDescription` keys to `Info.plist`:

```xml
<!-- Camera -->
<key>NSCameraUsageDescription</key>
<string>Used to take a profile photo.</string>

<!-- Microphone -->
<key>NSMicrophoneUsageDescription</key>
<string>Used for voice chat during online games.</string>

<!-- Photo Library -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to set your profile picture.</string>
```

**Step 2:** Add `PrivacyInfo.xcprivacy` (required for any used privacy API):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <!-- Add only APIs your app actually uses -->
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string><!-- Store user preferences -->
            </array>
        </dict>
    </array>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyTracking</key>
    <false/>
</dict>
</plist>
```

**Step 3:** Add privacy policy URL in App Store Connect → App Information → Privacy Policy URL.

---

### 3.1.1 — External Payment Link

**Bad — links outside App Store:**
```swift
// This WILL get rejected
Button("Upgrade to Premium") {
    UIApplication.shared.open(URL(string: "https://example.com/subscribe")!)
}
```

**Good — use StoreKit:**
```swift
import StoreKit

func purchasePremium() async throws {
    let products = try await Product.products(for: ["com.example.premium.monthly"])
    guard let product = products.first else { return }
    let result = try await product.purchase()
    switch result {
    case .success(let verification):
        // Handle successful purchase
    case .userCancelled, .pending:
        break
    @unknown default:
        break
    }
}
```

---

### 4.8 — Sign In with Apple Missing

**Requirement:** If your app offers any third-party login (Google, Facebook, Twitter), you must also offer Sign In with Apple.

**Add capability:** In Xcode → Target → Signing & Capabilities → `+` → "Sign in with Apple"

**Add button (SwiftUI):**
```swift
import AuthenticationServices

SignInWithAppleButton(.signIn, onRequest: { request in
    request.requestedScopes = [.fullName, .email]
}, onCompletion: { result in
    switch result {
    case .success(let auth):
        handleAppleSignIn(auth)
    case .failure(let error):
        print("Sign in with Apple failed: \(error)")
    }
})
.signInWithAppleButtonStyle(.black)
.frame(height: 50)
```

---

### 4.2 — Minimum Functionality

**Common causes:**
- App is a web view wrapper around a URL
- App has fewer than 3 distinct features
- App is a demo or prototype with placeholder content ("Lorem ipsum", "TBD", "Coming soon")

**Fix:** Remove all placeholder content. Ensure every listed feature in the App Store description is fully functional before submission.

---

## Step 5 — Pre-Submission Checklist

Run through this before resubmitting:

```
BUILD & STABILITY
[ ] App launches clean on a real device (not simulator)
[ ] All flows complete without crashes on iOS 16+ and iOS 17+
[ ] No placeholder text ("Lorem ipsum", "TODO", "Coming Soon")
[ ] No developer/debug UI visible (no test banners, no analytics overlays)
[ ] App works without network connection (or fails gracefully)

PRIVACY & PERMISSIONS
[ ] Every requested permission has an NSUsageDescription in Info.plist
[ ] PrivacyInfo.xcprivacy declares all accessed privacy APIs
[ ] Privacy policy URL is live and accessible
[ ] App Privacy answers in App Store Connect are accurate

METADATA
[ ] Screenshots show real app content on correct device sizes
[ ] App description is accurate to current build
[ ] Keywords don't include competitor names or banned words
[ ] Support URL and marketing URL are live

IAP & MONETIZATION
[ ] All digital purchases use StoreKit (no external links)
[ ] Restore Purchases button present if any IAP exists
[ ] Subscription terms clearly disclosed in the UI

CAPABILITIES
[ ] Entitlements file matches capabilities in Developer Portal
[ ] Push notification entitlement matches environment (dev vs prod)
[ ] Sign In with Apple added if any third-party login exists
```

---

## Step 6 — Draft App Store Connect Reply

Use this template when responding in Resolution Center:

```
Dear App Review Team,

Thank you for your feedback regarding [App Name] (Build [X.X.X], submitted [date]).

**Issue Identified:**
[One sentence: what the root cause was]

**Fix Applied:**
[Concrete, specific description of exactly what was changed]

Example (for 5.1.1):
We have added the required NSCameraUsageDescription key to Info.plist 
with a clear explanation of why the camera is used. We have also added 
a PrivacyInfo.xcprivacy file declaring NSPrivacyAccessedAPICategoryUserDefaults 
with reason code CA92.1.

**Testing Steps to Verify:**
1. [Step 1 to reproduce the original issue]
2. [Step 2 to confirm the fix]
3. [Expected result]

**Additional Notes (if any):**
[Any clarification the reviewer may need, e.g. demo credentials, 
test account, special instructions to access the feature]

Demo Account (if required):
Username: [test@example.com]
Password: [testpassword]

We have uploaded a new build ([X.X.X+1]) with the fix applied. 
Please let us know if any additional information is needed.

Thank you,
[Developer Name]
```

---

## Step 7 — Verify Before Resubmitting

- [ ] Root cause fixed in code and/or config
- [ ] Fix verified on a physical device (clean install)
- [ ] Archive built and uploaded via Xcode Organizer or Transporter
- [ ] New build number incremented (`CFBundleVersion`)
- [ ] App Store Connect reply drafted and submitted
- [ ] Resolution Center "Reply to Apple" sent before resubmitting

---

## Example Usage

### Sample Input

```
GUIDELINE: 5.1.1
REJECTION_DESCRIPTION: We found that your app collects user data without 
a clearly defined privacy policy. Specifically, the app accesses the camera 
but does not include NSCameraUsageDescription in Info.plist.
BUILD: 1.0.3 (build 12)
```

---

### AI Behavior

**Root cause (one sentence):**  
`NSCameraUsageDescription` is missing from `Info.plist`, triggering a 5.1.1 rejection.

**Fix:**  
Add to `Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Used to scan a QR code to join a private game room.</string>
```

**Verify:** Build and run on device — camera permission prompt now shows the description string.

**Reply template:** [Generated from the Step 6 template above with the specific fix filled in]

---

## Common Rejection Mistakes to Avoid

| Mistake | Why It Gets Rejected | How to Prevent |
|---|---|---|
| Submitting a Simulator build | Builds from Simulator can't be uploaded, but screenshots from it lack device frame | Always archive on a real device |
| Using `UIDevice.current.name` to fingerprint users | Privacy violation | Remove all device fingerprinting code |
| Showing App Store rating prompt too early | Must be triggered by a natural user action, max 3 times/year | Use `SKStoreReviewController.requestReview()` only after meaningful use |
| Hardcoded test credentials visible in UI | Reviewers flag debug UI | Use `#if DEBUG` guards around all test UI |
| Review demo account broken | Reviewer can't test the app | Always verify demo credentials work before submission |
| Screenshots show competitor app comparisons | Guideline 2.3 violation | Remove all comparison imagery |
| Privacy policy URL returns 404 | Automatic rejection | Verify URL is live before submitting |
