# Step 0.5 — Wiring the WematchTests target (Xcode GUI steps)

Everything on the file side is prepared (test files adapted, hermetic in-memory keychain,
new SyncGraph/TemporaryRoom/FirebaseSafe tests). The only remaining step must be done in
Xcode by Rémy — pbxproj surgery by hand is too fragile.

## Steps (≈ 3 minutes)

1. Xcode → open `Wematch.xcodeproj`.
2. **File → New → Target… → iOS → Unit Testing Bundle**
   - Product Name: `WematchTests` (exact — the folder already exists and will be picked up)
   - Team/Bundle ID: defaults are fine (`com.remyramadour.WematchTests`)
   - Target to be Tested: `Wematch`
3. Xcode creates a `WematchTests/` group. Because the folder already exists on disk with
   our test files, verify in the target's **Build Phases → Compile Sources** that ALL
   `.swift` files under `WematchTests/` are included (Authentication, Friends, Groups,
   Inbox, Rooms, Shared, Support subfolders). If Xcode created a synchronized folder
   reference (Xcode 26 default), this is automatic.
   - If Xcode generated a placeholder `WematchTests.swift` with an example test, delete it.
4. Target settings check (WematchTests → Build Settings):
   - `SWIFT_VERSION`: same as app (5.0 language mode for now — do NOT bump here;
     Swift 6 mode is plan step 1.10)
   - `SWIFT_DEFAULT_ACTOR_ISOLATION`: inherited `MainActor` is fine — test classes are
     `@MainActor` or isolation-neutral.
5. **Product → Test** (⌘U) with destination iPhone 17 Pro.

## Expected result

- All suites pass EXCEPT `TemporaryRoomTests.testExitRoomDeletesTempRoomWithCorrectSafeIDs`
  which **must fail** — it reproduces audit finding E1 (temp-room ID parsing truncates
  dotted Apple IDs). It stays red until plan step 1.9. Do not "fix" the test.
- If anything else fails: the test files may have bit-rotted against the current app API
  (they were never compiled since Sprint 4). Report failures back to Claude — do not patch
  blindly.

## CLI verification (after wiring)

```bash
xcodebuild test -scheme Wematch \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30
```

Note: the scheme must have the test target enabled (Product → Scheme → Edit Scheme → Test —
Xcode does this automatically when creating the target against the Wematch scheme).
