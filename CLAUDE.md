# Wematch — Project Instructions

iOS 26+ / watchOS 26+ app for real-time heart rate synchronization between users. Hearts of
room participants are plotted on a 2D graph (X = previous HR, Y = current HR, 40–200 BPM);
when hearts synchronize (< 5 BPM Euclidean distance), visual and haptic effects trigger.
First audience: Rémy's colleagues.

**Stack:** Swift 6, SwiftUI only, `@Observable` + `@MainActor`, async/await (no Combine,
no ObservableObject). Firebase RTDB (ephemeral real-time HR), CloudKit (persistent social
graph), HealthKit (Watch HR source), WatchConnectivity.
**Targets:** `Wematch` (iPhone), `WematchWatch Watch App`, `WematchShared` (empty — slated
for replacement by a local Swift package, see plan step 1.11).

## Current State

All 14 v1 sprints (0–13) are code-complete, but the project is in a **reboot**: a full audit
(`Docs/AUDIT-20260715.md`, finding IDs A1…I5) found 24 critical issues, and the remediation
roadmap is `Docs/plans/plan-20260715-reboot.md` (Phases 0–3). Work from that plan; reference
finding IDs in commits. Phase 0 is closed, Phase 1 is 6 steps of 11, Phase 2 exits on a real
two-person session that has not been run — `Docs/STATUS.md` carries the live version of this
paragraph and is the file to update, not this one.

**Nothing has ever run on real hardware.** The simulator uses `SimulatedHeartRateService`
and never exercises the Watch path, so no claim about heart rate or WatchConnectivity is
verified yet. Plan steps 1.1–1.3 (backend security) are done, which unblocks TestFlight.

## Critical Rules

### Git — NEVER without Rémy's explicit approval
- NEVER commit, merge, push, rebase, force-push, or delete branches/tags without approval.
  Staging (`git add`) and showing diffs is fine.
- Branch naming: `sprint/XX-short-description`. Prefixes: `feat:`, `fix:`, `refactor:`,
  `test:`, `docs:`, `chore:`.
- Reference the plan in commits, e.g. `fix(rooms): remove firebase listener leak (plan 1.5, C2)`.

### Code
- All code and UI text in English. "Wematch" everywhere (lowercase m), never "WeMatch".
- No force unwraps outside tests/previews. No `print()` — use `Log.category` (os.Logger).
- ViewModels depend on repository/service **protocols**, never concrete CloudKit/Firebase
  types, and never on singletons (`PhoneSessionManager.shared` is legacy debt — do not add
  new call sites; plan step 1.10 removes them).
- If a protocol doesn't cover a need, **extend the protocol** — never downcast to the
  concrete type (this is the root cause of half the audit findings).
- No new `@unchecked Sendable` without a written justification comment.
- No silent failure: errors at Firebase/CloudKit/WatchConnectivity boundaries must be
  logged AND surfaced (thrown or exposed as UI state). Never `try?` a write.
- Feature availability through `FeatureFlagProvider` (checked in ViewModels, not Views).

### Definition of Done (every change — plan 2.3)

Executable: each line is a command whose output can be pasted, or a box that can be
defended. A build succeeding is not evidence of anything.

```bash
# 1. Both affected targets build (canonical invocations: `wematch-build` skill)
xcodebuild -scheme Wematch -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build -quiet
xcodebuild -scheme "WematchWatch Watch App" -destination 'generic/platform=watchOS Simulator' build -quiet

# 2. Tests green — and new behaviour arrives with a test that failed before the change
xcodebuild test -scheme Wematch -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20

# 3. Lint clean, warnings included. No new `swiftlint:disable`, no raised limit
swiftlint --strict

# 4. Simulator pass for anything visible: one screenshot per appearance.
#    Name the device — `booted` picks an arbitrary one when several simulators are up
#    (it will happily screenshot a Vision Pro instead).
xcrun simctl ui "iPhone 17 Pro" appearance light   # then dark
xcrun simctl io "iPhone 17 Pro" screenshot ~/Desktop/wematch-light.png
```

5. **Screens behind Sign In** cannot be reached by launching the app. Two proven ways in:
   seed the state
   (`xcrun simctl spawn "iPhone 17 Pro" defaults write com.remyramadour.Wematch <key> <value>`)
   then launch, or render the view through the Xcode MCP `RenderPreview` with a
   `Color Scheme` variant override. Say which one was used.
6. **Device check** whenever the change touches heart rate, the Watch or WatchConnectivity.
   The simulator runs `SimulatedHeartRateService` and never exercises the Watch path at all,
   so a simulator pass says nothing here. Run the cases your change touches from
   `Docs/field-tests/session-script.md` and log the result in that directory.
7. **Accessibility** for new or changed UI: Dynamic Type at AX5, and VoiceOver reading whole
   facts rather than fragments. Scripted assertions need AXe (`xcui doctor --install`);
   until it is installed, check by hand and say so.
8. **Rémy's approval before commit.** The commit names the plan step and the finding IDs.

## Build Environment

Canonical build, test and run invocations live in the `wematch-build` skill and in the
Definition of Done above — do not improvise `xcodebuild` lines.

Simulators: iPhone 17 Pro, iOS 26.x. Xcode 26 uses `PBXFileSystemSynchronizedRootGroup` —
files added under `Wematch/` are auto-included in the target.

## Architecture Map

```
Wematch/
├── App/                 # WematchApp (entry, DI via .environment), MainTabView (5 tabs)
├── Core/                # Authentication, CloudKit, Firebase, HealthKit,
│                        # WatchConnectivity, FeatureFlags, Services (protocols), Design
├── Features/            # Rooms | Groups | Friends | Inbox | Settings | Dashboard
│   └── X/               # Views / ViewModels / Models / Repositories
└── Shared/              # Models, Extensions (String+FirebaseSafe), Utilities (Logger)
WematchWatch Watch App/  # Passive display: iPhone computes, Watch renders (keep it that way)
WematchTests/            # Unit tests (target wiring: plan 0.5)
```

Key data flow: Watch HealthKit workout → WCSession → `PhoneSessionManager` →
`RoomViewModel` → Firebase RTDB `rooms/{roomID}/users/{userID}` → all participants' plots.
Sync detection: `SyncGraph` (pure value type — Bron-Kerbosch cliques + BFS; the scientific
core, keep it isolated and tested).

## Known Gotchas (hard-won)

- Firebase RTDB paths can't contain `. # $ [ ]` → `String.firebaseSafe()` (dots→underscores).
  **Never parse business data back out of mangled path keys** (audit E1).
- Temp room IDs: `temp_{sorted_safe_A}_{sorted_safe_B}`, Firebase-only, index at
  `/tempRooms/{userID_safe}/{roomID}`.
- CloudKit: no OR predicates (parallel queries + merge); can't save empty arrays as first
  field value (skip field); catch `.unknownItem`/`.invalidArguments`/`.serverRejectedRequest`
  on first-use queries; use async `modifyRecords`, not `CKModifyRecordsOperation`+`add`.
- `Group` model clashes with `SwiftUI.Group` — qualify in views.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set project-wide — mind it for test code
  and nonisolated contexts.
- Watch HealthKit needs BOTH `NSHealthShareUsageDescription` and
  `NSHealthUpdateUsageDescription`.
- **`INFOPLIST_KEY_WKBackgroundModes` does not exist.** Xcode declares only
  `INFOPLIST_KEY_WKCompanionAppBundleIdentifier` and `INFOPLIST_KEY_WKWatchOnly`; any other
  `INFOPLIST_KEY_WK*` is accepted in the pbxproj and **silently dropped** from the generated
  plist. `WKBackgroundModes` (= `workout-processing`, without which a `HKWorkoutSession`
  runs only in the foreground) needs a real `Info.plist` on the Watch target. Always verify
  such settings in the *built* bundle: `plutil -p "…/Wematch.app/Watch/WematchWatch Watch
  App.app/Info.plist"` — the Watch scheme builds the iPhone app with the Watch app embedded,
  so the `Debug-watchsimulator` product goes stale and lies.
- Adding an `Info.plist` inside a `PBXFileSystemSynchronizedRootGroup` breaks the build with
  "Multiple commands produce …/Info.plist": the folder-sync copies it as a resource *and*
  the target consumes it as the Info.plist. Fix with a
  `PBXFileSystemSynchronizedBuildFileExceptionSet` listing `Info.plist` for that target —
  the `Wematch` group already has one, copy its shape.
- `WematchTypography` has no `subheadline` — use `callout`.
- Plot/HUD font sizes are intentionally fixed (data viz, not chrome) with explicit
  accessibility elements — keep the `RoomView` HUD pattern as the a11y template.

## Documents

- `Docs/STATUS.md` — **where the reboot actually stands. Read this first.**
- `Docs/AUDIT-20260715.md` — audit findings (the "why" behind current work)
- `Docs/plans/plan-20260715-reboot.md` — active roadmap (Phases 0–3)
- `Docs/decisions/` — one file per methodological choice, with the measurement behind it
- `Docs/field-tests/` — the two-person session protocol, and the log of sessions run
- `Docs/design-brief.md` — the validated design record. **When it and a Figma comp
  disagree, the brief wins**
- `Docs/CAHIER_DES_CHARGES.md` — v1 product spec
- `Docs/SPRINTS.md` — historical v1 sprint plan (done)
- `Docs/CLAUDE-v1-archive.md` — archived original project instructions
