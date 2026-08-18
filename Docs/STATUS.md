# Status

Plan step 2.5. Where the reboot actually stands. Update this at the end of every sprint —
before the branch is merged, while the answers are still true.

**Last updated:** 2026-08-17 · **Branch:** `sprint/18-phase2-close` · **`main`:** `ef8d5bf`

## Health

| | |
|---|---|
| Tests | 151 passing, 0 failing (`ef8d5bf`) |
| Lint | `swiftlint --strict` clean, 164 files |
| CI | green on PRs — build ×2 targets, tests, Firebase rules |
| Distributed | nothing yet, not even TestFlight |
| Verified on a real device | **nothing** |

That last line is the one that matters. Every claim in this repo rests on the simulator,
which runs `SimulatedHeartRateService` and never exercises the Watch path.

## Phases

**Phase 0 — healthy environment: done.** Test target wired, first real tests, SwiftLint
baseline, CI (`fcf47be`).

**Phase 1 — secure and stabilize: 6 of 11 steps done.**

| Step | State |
|---|---|
| 1.1 Firebase Auth + RTDB rules | done |
| 1.2 Social graph on Firestore, CloudKit purged | done — see [0001](decisions/0001-firestore-for-the-social-graph.md) |
| 1.3 Privacy manifest, Keychain ACL, private HR logs | done |
| 1.4–1.6 Room teardown, listener unwind, scenePhase | done |
| 1.7 Error paths; connection-state indicator (D1–D3) | **open** |
| 1.8 CloudKit robustness (D4) | **open** — re-scope: the CloudKit layer is gone |
| 1.9 Temp-room ID parsing (E1) | done early, in 1.2c |
| 1.10 The two unsafe `@unchecked Sendable`; typed WatchMessage | **open** |
| 1.11 `WematchShared` → local Swift package | **open** |

**Phase 2 — robust method: 2.1–2.3 and 2.5 done, 2.4 written but not run.**
The Figma library and the six screens are the source of truth and match the code; the
design system is backported (`ef8d5bf`); the Definition of Done in `CLAUDE.md` is now
executable. `Docs/field-tests/` holds the protocol — **no session has been run.**

**Phase 3 — finish the product: not started.** Two pieces landed early during the design
backport: G4 (destructive confirmations, loading and error surfaces) and part of G3 (Reduce
Motion, Watch labels). 3a (hot-path performance), the rest of 3b, and 3c are untouched.

## Next

1. **Run the field session** (2.4). It is the Phase 2 exit criterion and the only thing that
   can tell us whether any of this works. Needs a colleague, two Watches, a TestFlight
   build. `WKBackgroundModes` = `workout-processing` is now declared on the Watch target —
   without it the workout session would have run only in the foreground and the session
   would have measured a missing capability. Two distribution decisions remain open in
   `field-tests/testflight-setup.md`.
2. **1.7** — the field script's cases S8 and S9 will make the case for it in numbers: today
   an offline phone and a frozen heart look exactly like a working room.
3. **1.10** — the remaining unsafe concurrency sits directly under real HR streaming, which
   the field session is about to exercise for the first time.

## Found in passing, not in the plan

Noticed while doing other work. Recorded here because `AUDIT-20260715.md` is dated and
frozen — retro-fitting findings into it would make it a document that cannot be trusted as
a snapshot. An unwritten finding is one that gets re-discovered.

**The `Task.detached` that never leaves the main actor.** `DashboardRecordStoring` is not
`nonisolated`, so the project-wide `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` applies to
its methods, and `Task.detached { try store.load() }` hops straight back to the main actor.
The comment above it claims the read is off the main actor to avoid a hitch on the plot;
it is not. Step 1.10's acceptance ("zero warnings") *will* force someone to touch these two
lines — and the cheapest way to satisfy it is to add `await`, which silences the warning and
freezes the read on the main actor permanently. **Fix the isolation, not the warning.**
`Wematch/Features/Rooms/ViewModels/RoomViewModel+DashboardRecording.swift:94` and
`Wematch/Features/Dashboard/ViewModels/DashboardViewModel.swift:65`. Belongs to 1.10.

| What | Where | Belongs to |
|---|---|---|
| `send(message:)` is `throws` but returns *normally* when the Watch is unreachable: it logs, and the caller cannot tell "sent" from "dropped". Contradicts the no-silent-failure rule | `Core/WatchConnectivity/PhoneSessionManager.swift:46` | 1.7 (D1) |
| The iPhone's `NSHealthUpdateUsageDescription` describes *reading* ("fetch heartrate from the Apple Watch"), but the phone never writes to HealthKit — reading is covered by `NSHealthShareUsageDescription`, which is present in `Wematch/Info.plist`. Harmless until a write is requested, then it shows the wrong sentence to the user | `Wematch.xcodeproj/project.pbxproj` | 3b (F6) |

## Blocked on Rémy

- Anything on real hardware: the device pass, the field session, TestFlight upload.
- Xcode target surgery (1.11), done in the GUI.
- The three distribution decisions in `field-tests/testflight-setup.md`.
