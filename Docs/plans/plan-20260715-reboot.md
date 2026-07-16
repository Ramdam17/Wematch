# Plan: Wematch Reboot — Environment, Security, Method, Product
**Date:** 2026-07-15
**Basis:** `Docs/AUDIT-20260715.md` (finding IDs referenced as A1…I5)
**Estimated complexity:** XL (4 phases, ~10 sprints)

---

## Problem Statement

All 14 v1 sprints are "done" but the app was never verified against reality: 0 % executable
test coverage (A3), no backend access control (B1/B2), a room lifecycle that leaks HR data and
battery (C1/C2), and no visual source of truth (A7). Goals: (1) a healthy, performant working
environment, (2) a robust method whose "done" is executable, (3) this exhaustive plan,
(4) an app actually usable by colleagues — and fun getting there.

## Approach Rationale

**Repair, not rewrite.** The audit shows the structure is sound (I1–I5); the failures cluster in
three families — lifecycle teardown, silent boundaries, implicit trust — which are fixable as
systematic passes. A rewrite would discard the good repository layer and re-import the same
boundary bugs.

**Order: environment → security → method → product.** Tests and tooling first because every
later fix needs a safety net. Security before features because live heart-rate data of real
colleagues is exposed (B1/B2) — nothing ships, even to TestFlight, before that closes.
Design (Figma) runs early in Phase 2 so product fixes in Phase 3 land on validated screens.

**Rules carried over (unchanged):** never commit/merge/push without Rémy's explicit approval;
branch naming `sprint/XX-name`; every result that looks unexpected is flagged, not silently
worked around.

---

## Phase 0 — Healthy Environment (complexity M, ~1 sprint)

Goal: a session of Claude Code that knows the project, a test suite that runs, a repo that is clean.

| # | Step | Findings | Acceptance (executable) |
|---|------|----------|------------------------|
| 0.1 | Review + commit the pending Feb-17 diff (real bugfix E3 + Watch wake-up) | E3 | `git status` clean; fix verified in simulator |
| 0.2 | Repo hygiene: extend `.gitignore` (`firebase-debug.log`, `.serena/`, `.DS_Store`), remove stray log | A6 | `git status` shows no untracked noise |
| 0.3 | Root `CLAUDE.md`: rewritten, current-state (post-Sprint-13), merging the still-valid rules of `Docs/CLAUDE.md`; keep the old one as `Docs/CLAUDE-v1-archive.md` | A2 | New session auto-loads project rules |
| 0.4 | Project `.claude/`: `settings.json` (permission allowlist: xcodebuild, xcrun simctl, swiftlint), skill `wematch-build` (canonical build/test/run commands), optional PostToolUse hook running a targeted build check on Swift edits | A1 | Build/test runs without permission prompts; skill invocable |
| 0.5 | **Wire the `WematchTests` target in Xcode** (Rémy does the Xcode-GUI step; Claude prepares everything else). Handle `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (H7): annotate/adapt test classes, make mocks `Sendable`, replace real-Keychain usage with an injected in-memory keychain | A3, H7 | `xcodebuild test -scheme Wematch` → green, in CI-able form |
| 0.6 | First real tests: `SyncGraph` (Bron-Kerbosch cliques, BFS diameter, threshold edges — synthetic fixtures with known answers), `firebaseSafe()` round-trips, temp-room ID build/parse | I3, E1 | New tests pass; E1 bug reproduced by a failing test *before* the Phase-1 fix |
| 0.7 | SwiftLint config aligned with existing conventions; zero-warning baseline | A4 | `swiftlint` exits 0 |
| 0.8 | Minimal CI (GitHub Actions, macOS runner): build iPhone + Watch, run tests on every PR | A4 | CI badge green on a test PR |

## Phase 1 — Secure & Stabilize (complexity XL, ~3 sprints)

Nothing is distributed (even TestFlight) before 1.1–1.3 are done.

### Sprint 1a — Backend access control
| # | Step | Findings | Acceptance |
|---|------|----------|-----------|
| 1.1 | Firebase Auth (Sign in with Apple token → Firebase credential, or anonymous+UID binding — decision below) + security rules: only authenticated room members read/write `rooms/{roomID}`; rules versioned in repo (`firebase/database.rules.json` + `firebase.json`) and deployed via CLI | B2, A5 | Unauthenticated `curl` on RTDB → permission denied; rules file in git; emulator-based rules tests pass |
| 1.2 | CloudKit access model redesign — **the structuring decision of the plan** (options analysed below, requires Rémy's arbitration) | B1 | No cross-user query can read non-shared social data (verified with 2 test accounts) |
| 1.3 | `PrivacyInfo.xcprivacy` (HealthKit, user ID, required-reason APIs); Keychain ACL → `.whenUnlockedThisDeviceOnly`; OSLog `.private` for HR values | B3, B4, B5 | Privacy report in Xcode clean; grep shows no public HR interpolation |

### Sprint 1b — Pass A: lifecycle
| # | Step | Findings | Acceptance |
|---|------|----------|-----------|
| 1.4 | RoomView teardown: `.onDisappear` → `exitRoom()`, handle swipe-back and auth-transition (sign-out cancels room tasks); `deinit` assertion in DEBUG | C1 | Enter room → swipe back → Firebase node removed, Watch workout stopped (verified via RTDB console + Watch) |
| 1.5 | `observeParticipants`: check `Task.isCancelled` / use `onTermination` to remove the Firebase listener; clear `heartRateHandler` on exit | C2, C4 | Listener count back to 0 after exit (Firebase debug logging) |
| 1.6 | App-wide `scenePhase`: pause `AnimatedBackground` (and all `repeatForever`) in background/inactive; cap `SyncStar` count | F3, F4 | Instruments/energy gauge: idle background CPU ≈ 0 % |

### Sprint 1c — Pass B: boundaries + Pass C: real Sendable
| # | Step | Findings | Acceptance |
|---|------|----------|-----------|
| 1.7 | Error paths: `AsyncThrowingStream` + Firebase `withCancel` in `observe`; remove mock-fallback in release (fail loudly); log dropped CloudKit records; `InboxMessageType.unknown`; connection-state indicator surfaced to RoomView | D1, D2, D3 | Simulated permission-denied shows an error state in UI, not an empty room |
| 1.8 | CloudKit robustness: `serverRecordChanged` retry on `Group.memberIDs` and friend acceptance; basic `CKError` taxonomy (retryable vs fatal) in one shared helper | D4 | Concurrent member-add test (2 devices) loses no member |
| 1.9 | Fix E1 (temp-room ID parsing) properly: stop parsing IDs out of path keys — store member IDs in room metadata | E1 | 0.6's failing test now passes |
| 1.10 | Concurrency: replace the 2 proven-unsafe `@unchecked Sendable` (WatchHeartRateManager, HealthKitHeartRateService) with actor/lock designs; justify or remove the remaining ones; typed `Codable` WatchMessage replacing `[String: Any]` (resurrect H2's dead code) | C3, H2 | Full Swift 6 strict concurrency build: zero warnings, zero `@unchecked` without a written justification comment |
| 1.11 | `WematchShared` framework → local multiplatform Swift package (Bezier math, plot coordinates, Color+Hex, participant model, WatchMessage) consumed by both targets | H1 | Both targets build; duplicated files deleted (~500 lines removed) |

## Phase 2 — Robust Method (complexity M, ~1–2 sprints, partly parallel with Phase 1)

| # | Step | Findings | Acceptance |
|---|------|----------|-----------|
| 2.1 | Design brief via design-consultant agent (audience: colleagues; identity: Rainbow Unicorn × Liquid Glass) → `Docs/design-brief.md` | A7 | Brief validated by Rémy |
| 2.2 | Figma: design-system library from the existing code components (tokens, GlassCard, GradientButton, StatusBadge…) — fixing G2 contrast at the token level — then the 6 core screens | A7, G2 | Figma file is the source of truth; StatusBadge tokens pass WCAG AA (4.5:1) |
| 2.3 | Executable definition of done, written into root `CLAUDE.md`: build ✚ tests ✚ simulator pass (simulator-tester agent: screenshots + accessibility tree) ✚ device checklist for HR features | A3, A4 | Every subsequent sprint closes with this checklist attached |
| 2.4 | Field protocol: TestFlight setup + a written 2-person / 2-Watch session script (join, sync, leave, kill-app, airplane-mode cases) with expected outcomes | — | One full session run with a colleague, results logged in `Docs/field-tests/` |
| 2.5 | Sprint hygiene v2: plans in `Docs/plans/`, one decision log per methodological choice, `sprint-sync` style status file | A8 | This plan referenced from commits |

## Phase 3 — Finish the Product (complexity L, ~3 sprints)

### Sprint 3a — Hot path performance
Cache `syncGraph` (recompute only on participant change) (F1); `Equatable` on
`RoomParticipant`/`WatchParticipant` (F2); per-child Firebase observation or in-repo diffing
(F2); fix `ClusterCircleView` scans + BFS dequeue (F5); parallelize `fetchDetails` (F5).
**Acceptance:** Instruments trace at 20 simulated participants: stable 60 fps, syncGraph
computed ≤ 1× per tick.

### Sprint 3b — UX & accessibility
Sign-In rewired natively (G1, test under VoiceOver); confirmations on destructive actions +
"Open Settings" on HealthKit denial + loading states (G4); Reduce Motion + plot VoiceOver
summary + Watch labels (G3); remove unused entitlements (F6); decision iPad: recommend
dropping `TARGETED_DEVICE_FAMILY=2` for v1 (G5).
**Acceptance:** accessibility-auditor re-run: 0 CRITICAL; manual VoiceOver sign-in works.

### Sprint 3c — Structural cleanup & navigation
Extract `SyncEffectsService` from RoomViewModel (H3); fix the 2 MVVM bypasses (H4); unify VM
creation pattern + introduce a minimal composition root (H5); move InboxMessageRepository (H6);
navigation coordinator with single room source of truth + `.onOpenURL` deep-link skeleton (G6, E2).
**Acceptance:** swift-reviewer re-run on Rooms/Groups: no CRITICAL; entering the same room
from 2 tabs impossible.

### Phase 3+ — v2 backlog (post-reboot, separate plan)
Real dashboards, dark cosmic theme, remote feature flags, push notifications (needs the
deep-link work), localization FR.

---

## Key Decisions Requiring Rémy's Arbitration

1. **CloudKit access model (1.2)** — options:
   a) Private DB + CKShare per group/friendship (most secure, most work, CloudKit-idiomatic);
   b) Keep public DB but move sensitive fields into opaque server-validated records — weak;
   c) Migrate social graph to Firebase (Firestore) under the same Auth as RTDB — one backend,
      one rules language, but abandons CloudKit work.
   Preliminary recommendation: **(a)**, evaluated in a spike before committing.
2. **Firebase Auth mode (1.1)**: Sign in with Apple federated into Firebase Auth (clean,
   one identity) vs anonymous auth + UID claim (fast, weaker). Recommendation: federated SIWA.
3. **iPad (G5)**: drop or design. Recommendation: drop for v1.
4. **CI runner (0.8)**: GitHub-hosted macOS (Xcode 26 availability to verify) vs self-hosted
   on the dev Mac. To validate at 0.8.

## Risks & Unknowns

- **CloudKit public→private migration** is the largest unknown (data migration for existing
  test records, CKShare complexity) → mitigated by a time-boxed spike with 2 test accounts
  before Sprint 1a commits to it.
- **Xcode target surgery** (0.5 test target, 1.11 package migration) is fragile in pbxproj →
  done in Xcode GUI by Rémy with Claude preparing files/instructions; verified by CI build.
- **Firebase rules + existing anonymous data**: enabling Auth breaks current unauthenticated
  clients → acceptable (no external users yet), old data wiped.
- **Swift 6 strict pass (1.10)** may surface deeper races in WCSession handling → budgeted as
  its own step, not a side-task.

## Verification Plan (plan-level)

- [ ] Phase 0 exit: CI green (build ×2 targets + tests), root CLAUDE.md loaded, lint clean.
- [ ] Phase 1 exit: security re-audit (security-privacy-scanner) → 0 CRITICAL; room
      enter/exit/sign-out leaves zero Firebase listeners, zero Watch workout, zero tasks.
- [ ] Phase 2 exit: Figma library live; one real 2-person field session logged.
- [ ] Phase 3 exit: full health-check re-run → 0 CRITICAL, HIGH count < 10; 60 fps at 20
      participants; VoiceOver end-to-end pass.

## Definition of Done (per sprint, from 2.3 onward)

- [ ] `xcodebuild test` green (both targets where applicable)
- [ ] SwiftLint clean
- [ ] Simulator pass with screenshots (simulator-tester)
- [ ] Device check for HR-touching changes
- [ ] Sprint decisions logged; plan updated if deviated
- [ ] Rémy's approval before commit/merge

---

*Changes during implementation must be noted below with date.*
