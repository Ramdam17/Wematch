---
name: wematch-build
description: Canonical build, test, and simulator-run commands for the Wematch project (iPhone + Watch targets). Use whenever building, testing, or verifying Wematch — do not improvise xcodebuild invocations.
---

# Wematch — Build & Verify

Always use these exact invocations (destinations and scheme names are load-bearing:
the Watch folder/scheme contains spaces; simulators are iPhone 17 Pro / iOS 26.x).

## Build

```bash
# iPhone app
xcodebuild -scheme Wematch \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build -quiet

# Watch app
xcodebuild -scheme "WematchWatch Watch App" \
  -destination 'generic/platform=watchOS Simulator' build -quiet
```

`-quiet` keeps output readable; on failure, re-run WITHOUT `-quiet` and read the full error.
Never suppress output beyond `-quiet`.

## Test (once WematchTests target is wired — plan 0.5)

```bash
xcodebuild test -scheme Wematch \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -50
```

## Run in simulator

```bash
xcrun simctl boot "iPhone 17 Pro" 2>/dev/null || true
xcodebuild -scheme Wematch \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcrun simctl install "iPhone 17 Pro" \
  ~/Library/Developer/Xcode/DerivedData/Wematch-*/Build/Products/Debug-iphonesimulator/Wematch.app
xcrun simctl launch "iPhone 17 Pro" com.remyramadour.Wematch
```

## Rules

- Long builds: run in background, keep working, read the tail on completion.
- A change is NOT verified by "it compiles" — see Definition of Done in root CLAUDE.md
  (tests + lint + simulator pass; real device for HR/Watch changes).
- Build failures: prefer the axiom:build-fixer agent over manual guessing (zombie
  processes, DerivedData, SPM cache are the usual suspects).
- Firebase runtime behavior can't be verified in unit tests — needs simulator with
  `GoogleService-Info.plist` present (gitignored, must exist locally).
