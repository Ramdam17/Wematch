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

## Current State (2026-07)

All 14 v1 sprints (0–13) are code-complete, but the project is in a **reboot**: a full audit
(`Docs/AUDIT-20260715.md`, finding IDs A1…I5) found 24 critical issues, and the remediation
roadmap is `Docs/plans/plan-20260715-reboot.md` (Phases 0–3). Work from that plan; reference
finding IDs in commits. **Nothing is distributed (even TestFlight) before plan steps 1.1–1.3
(backend security) are done.**

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

### Definition of Done (every change)
1. `xcodebuild build` passes on affected targets;
2. `xcodebuild test -scheme Wematch` green (once target is wired — plan 0.5);
3. SwiftLint clean;
4. Simulator verification for UI changes; real-device check for HR/Watch changes;
5. Rémy's approval before commit.

## Build & Test Commands

```bash
# iPhone
xcodebuild -scheme Wematch -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
# Watch
xcodebuild -scheme "WematchWatch Watch App" -destination 'generic/platform=watchOS Simulator' build
# Tests (after plan 0.5)
xcodebuild test -scheme Wematch -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

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
- `WematchTypography` has no `subheadline` — use `callout`.
- Plot/HUD font sizes are intentionally fixed (data viz, not chrome) with explicit
  accessibility elements — keep the `RoomView` HUD pattern as the a11y template.

## Documents

- `Docs/AUDIT-20260715.md` — audit findings (the "why" behind current work)
- `Docs/plans/plan-20260715-reboot.md` — active roadmap (Phases 0–3)
- `Docs/CAHIER_DES_CHARGES.md` — v1 product spec
- `Docs/SPRINTS.md` — historical v1 sprint plan (done)
- `Docs/CLAUDE-v1-archive.md` — archived original project instructions
