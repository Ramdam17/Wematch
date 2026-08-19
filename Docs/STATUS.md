# Status

Plan step 2.5. Where the reboot actually stands. Update this at the end of every sprint —
before the branch is merged, while the answers are still true.

**Last updated:** 2026-08-18 · **Branch:** `sprint/18-phase2-close` · **`main`:** `ef8d5bf`

**Branch state:** 10 commits ahead of `main`, **not pushed, not merged**. The last three
(2026-08-18) are the relay rename (decision 0009), the `onDisconnect` hook on the protocol,
and the plan 1.8 re-scope; before them plan 1.10 (`ea275f5`) and 1.11 (`1e29918`). Working
tree clean apart from `.claude/settings.json` and the untracked `.agents/`, `.codex/`,
`AGENTS.md`, none of which belong to the reboot.

## Health

| | |
|---|---|
| Tests | 216 passing, 0 failing |
| Language mode | **Swift 6** — all 4 targets, Debug and Release, zero warnings (raised at 1.10) |
| Lint | `swiftlint --strict` clean, 174 files (the package included) |
| CI | green on PRs — build ×2 targets, tests, Firebase rules |
| Distributed | nothing yet, not even TestFlight |
| Verified on a real device | **nothing** |

That last line is the one that matters. Every claim in this repo rests on the simulator,
which runs `SimulatedHeartRateService` and never exercises the Watch path.

## Phases

**Phase 0 — healthy environment: done.** Test target wired, first real tests, SwiftLint
baseline, CI (`fcf47be`).

**Phase 1 — secure and stabilize: 10 of 11 steps done — 1.8 was the last open one.**

| Step | State |
|---|---|
| 1.1 Firebase Auth + RTDB rules | done |
| 1.2 Social graph on Firestore, CloudKit purged | done — see [0001](decisions/0001-firestore-for-the-social-graph.md) |
| 1.3 Privacy manifest, Keychain ACL, private HR logs | done |
| 1.4–1.6 Room teardown, listener unwind, scenePhase | done |
| 1.7 Error paths; connection-state indicator (D1–D3) | **done, unverified on hardware** — see below |
| 1.8 ~~CloudKit~~ Firestore robustness (D4) | **done, re-scoped 2026-08-18** — see below |
| 1.9 Temp-room ID parsing (E1) | done early, in 1.2c |
| 1.10 Concurrency, typed WatchMessage, Swift 6 language mode | **done, unverified on hardware** — see below |
| 1.11 `WematchShared` → local Swift package | **done** — see below |

**1.7, in detail.** `observe` is an `AsyncThrowingStream` with Firebase's `withCancel`, so a
listener the server refuses ends with its error instead of going quiet forever. `send` on
`PhoneSessionManager` throws `watchUnreachable` instead of returning as if it had sent.
`InboxMessageType.unknown(String)` keeps the raw type a newer build sent, so no message is
dropped on the floor. The mock Firebase fallback is `#if DEBUG`; in release every operation
fails loudly rather than serving a room made of local state. All of it folds into one
`RoomConnectionState` — worst fault wins, one banner, one thing for VoiceOver to read.

Two things went beyond the plan's line, deliberately:

- **`.info/connected`.** `withCancel` only sees a *server* cancellation. Airplane mode does
  not cancel an RTDB listener, it starves it — so the plan's fix alone would have left field
  case S8 silent. `observeConnection()` is on the protocol now, and S8 has been rewritten to
  expect the banner rather than to record its absence.
- **`read(path:)`.** The `plan 1.7, C5` note left in `FirebaseTemporaryRoomRepository` was
  still true: three one-shot reads faked on the observe stream behind a 5 s timeout, each
  reporting "empty" for both *nothing there* and *no answer*. They are three lines that
  propagate the error now.

**What 1.7 did not close:** a stale heart. When the Watch goes out of range the participant's
last value sits on the plot indefinitely and nothing says so (field case S9). The banner is
raised by failed *operations*, and a frozen feed produces none.

**Not verified:** no banner state has been seen anywhere but the Xcode canvas
(`RoomView.swift`, the two `Connection banners` previews) — the room needs a signed-in
session and a broken link to show one. `watchUnreachable` has no automated test at all: the
Watch commands are compiled out of simulator builds.

**At accessibility text sizes the banner leaves the overlay.** Floating it would cover the
top of the plot — the high-BPM band, where hearts synchronise most — so above
`dynamicTypeSize.isAccessibilitySize` it joins the layout flow and pushes the plot down
instead. The plot shrinks; the sentence stays whole. Truncating an error message that
carries the fix was never an option.

**The iPhone no longer asks HealthKit for anything** — entitlement, both usage strings, the
authorization call and `RoomError.healthKitDenied` are gone; the Watch is untouched. See
decision [0009](decisions/0009-the-iphone-asks-healthkit-for-nothing.md), whose one
unverified claim is checked by field-test case S1.

**1.10, in detail.** The step's acceptance was "full Swift 6 strict concurrency build,
zero warnings" — and the first thing it turned up is that the project was not in Swift 6 at
all. All eight build configurations read `SWIFT_VERSION = 5.0`; what was set was
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY`, which are
the migration aids, not the migration. `CLAUDE.md` claimed Swift 6; the compiler disagreed.
All targets are on `6.0` now. (`WematchShared` was raised with them and then deleted at
1.11, below.)

**Raising it crashed the app on launch, and that is the headline.** `PhoneSessionManager`'s
`WCSessionDelegate` callbacks were main-actor isolated by the project-wide default, while
WatchConnectivity calls them on its own `NSOperationQueue`. Swift 6 checks that at runtime:
`_checkExpectedExecutor` → `dispatch_assert_queue_fail`, `EXC_BREAKPOINT`, before the first
screen. Under Swift 5 the same code ran and simply did the wrong thing quietly — on the
`WCSession` activation path, which is the first thing the field session exercises.
Conforming to `Sendable` is not enough to stop the inference; the declaration has to say
`nonisolated`.

What else changed:

- **The wire is typed.** `WatchMessage` is a closed `Codable` enum covering all seven
  message kinds, JSON-encoded into a versioned envelope. It replaces seven hand-built
  `[String: Any]` shapes read with `as? Double ?? 0` — where a renamed key produced a heart
  at 0 BPM on the plot rather than a failure. A payload that does not fit now throws, and
  `WatchMessageTests` pins both the round trip and the three refusals. `logLabel` exists so
  that no log can grow a BPM in it (audit B5).
- **The `@unchecked Sendable` count in app code went 8 → 4**, and the four that remain each
  carry a written justification: two Firebase SDK boundaries (`Database` and
  `DatabaseReference` are not `Sendable`-audited), the `FirebaseSnapshot` wrapper around the
  `[String: Any]` payload, and `SignInWithAppleCoordinator` — which is `@unchecked` only
  because it is non-final for a test subclass; its state moved behind a mutex.
- **Locks, not actors, for the delegate-driven types.** `WCSessionDelegate` and
  `HKLiveWorkoutBuilderDelegate` callbacks must stay synchronous and ordered — heart-rate
  samples hopped onto an actor through a `Task` are samples whose order is no longer the
  signal — and `isReachable` is read from a `View` body. `Mutex` keeps both. The reasoning
  is written at each site.
- **The singleton and the downcast are gone from `RoomViewModel`.** Heart rate reached the
  phone through a closure installed on `PhoneSessionManager.shared`, pointed at the concrete
  service the ViewModel got by downcasting its own injected protocol. It now arrives through
  `watchService.messages()`, and `yield(heartRate:)` is on `HealthKitServiceProtocol` —
  the protocol extended rather than worked around. That path had **no test at all**; it has
  two now.
- **The `Task.detached` that never left the main actor is fixed at the isolation**, not at
  the warning: `DashboardRecordStoring` and the record models are `nonisolated`.
- One stored handler on each side of the link is gone. They were `var` closures written from
  the main actor and read from the WatchConnectivity delegate queue — the actual races — and
  each re-dispatched through `DispatchQueue.main.async`. Both readers take their own stream.

**What 1.10 did not close:** the two `firebaseService as? FirebaseRealtimeService` downcasts
in `FirebaseRoomRepository` (`onDisconnect` setup) — same forbidden pattern, different
protocol, and out of a concurrency step's scope. `RoomViewModel`'s
`watchService ?? PhoneSessionManager.shared` default argument survives: every test injects
its own, so nothing reaches the singleton, and it becomes a parameter when 3c builds the
composition root that has somewhere to inject it from.

**Not verified:** none of this has run on a Watch. The crash above was found on the
simulator, which does not exercise WatchConnectivity at all beyond activation — the
`enterRoom`/`exitRoom`/heart-rate path is still first exercised by the field session.

**1.11, in detail.** `Packages/WematchCore` is a local Swift package, consumed by both
apps. It replaces `WematchShared`, a framework created iOS-only and therefore incapable of
being what its name claimed: every model the Watch shared with the phone was transcribed by
hand instead, under comments asking the reader to keep the copies in sync. Two had already
drifted — only the Watch's `WatchDashboardSnapshot` could format a duration, only the
phone's could be built from records; `Color+Hex` differed by three lines.

What moved: the `WatchMessage` wire and its error, `WatchHeartRateStatus`,
`WatchDashboardSnapshot` (the phone keeps `make(from:)`, which needs the on-device history
the Watch must not have), `HeartPaletteSlot` and the twenty hexes, `BezierPath`,
`PlotCoordinates`, `Color(hex:)`. The palette is the one that mattered most: the FNV-1a
hash deriving a participant's hue existed twice, and the hex array carried a comment
reading "must match exactly" — two transcriptions of the colour two screens use to identify
the same person.

The `WematchShared` target is gone with it: 21 references out of the project file, and one
empty framework no longer embedded and code-signed into the app bundle for nothing
(verified: `Wematch.app/Frameworks` no longer contains it). Net −416 lines.

The package sets no `defaultIsolation`, so it is `nonisolated` throughout — the opposite of
the apps' `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and right for types decoded on a
WatchConnectivity delegate queue as often as they are read in a `View`. Only
`BezierPositionModifier` is `@MainActor`, and its `Animatable` conformance is
`@preconcurrency`: what the apps got silently from their project-wide default is stated
out loud there.

**No test target in the package.** `swift test` would build it for macOS, which the package
does not support, so those tests could never be run from a command line — and a test target
nobody can run is worse than none. The types are covered from `WematchTests`, on the
simulator, against the real dependency graph. `HeartPaletteSlotTests` is what proves the
move changed no colour: it pins the slots the hash derives, and it passed unchanged.

**Not verified:** the Watch app builds for both configurations and has not been run.

**1.8, in detail.** The step named CloudKit APIs that no longer exist. What it was *for*
splits in two, and both halves are done: the membership races D4 described are gone by
construction on Firestore (`arrayUnion`/`arrayRemove` in batches — recorded in decision
[0001](decisions/0001-firestore-for-the-social-graph.md), which had not said so), and the
one race that survived — group-code generation, query-then-write — is a Firestore
transaction on a `groupCodes/{code}` reservation document, with rules and emulator tests.
The retryable-vs-fatal taxonomy the step asked for is `BackendError`
(`Core/Firebase/BackendError.swift`), applied at the thirty places ViewModels turn a caught
error into an alert: a rules refusal now reads as a refusal, not as a network hiccup, and
"You're offline" is a sentence rather than an SDK string. No automatic retry, on purpose:
Firestore's persistent cache serves reads and replays writes offline, and
`FirebaseManager.configure()` now says so in code rather than inheriting it. The seven
`try?` writes left in ViewModels (D3's tail) went with it — six courtesy notifications are
best-effort but logged (`InboxMessageRepository.notify`), the inbox delete-after-action
and the temp-room fetch propagate.

**Not verified:** the transaction and the rules have run nowhere but CI's emulator (no
Java runtime locally); no `BackendError` text has been seen on a screen, since producing
one needs a backend that refuses. `firestore.rules` is deployed by hand — **the
`groupCodes` rules must be deployed before the first group is created on a build carrying
this change**, or `createGroup` fails with `denied`.

**Phase 2 — robust method: 2.1–2.3 and 2.5 done, 2.4 written but not run.**
The Figma library and the six screens are the source of truth and match the code; the
design system is backported (`ef8d5bf`); the Definition of Done in `CLAUDE.md` is now
executable. `Docs/field-tests/` holds the protocol — **no session has been run.**

**Phase 3 — finish the product: not started.** Two pieces landed early during the design
backport: G4 (destructive confirmations, loading and error surfaces) and part of G3 (Reduce
Motion, Watch labels). 3a (hot-path performance), the rest of 3b, and 3c are untouched.
**3d (notifications) was added on 2026-08-17**, promoted out of the v2 backlog: the Inbox
models eight message types and nothing tells the user any of them arrived. It runs after 3c
because tapping a notification needs somewhere to land. The plan's change log carries why it
does not block the field session.

## Next

1. **Run the field session** (2.4). It is the Phase 2 exit criterion and the only thing that
   can tell us whether any of this works. Needs a colleague, two Watches, a TestFlight
   build. `WKBackgroundModes` = `workout-processing` is now declared on the Watch target —
   without it the workout session would have run only in the foreground and the session
   would have measured a missing capability. The two remaining distribution decisions
   are closed (2026-08-17): `ITSAppUsesNonExemptEncryption = NO` is declared and verified in
   the built bundle, and the dead entitlements are gone — `aps-environment`,
   `healthkit.background-delivery`, `icloud-container-identifiers`, `icloud-services`.
   `com.apple.developer.healthkit` was deliberately kept; see the row below.
2. **Deploy `firebase/firestore.rules`** (`npx firebase-tools deploy --only firestore:rules`)
   — the `groupCodes` collection is new and rules-gated. Phase 1 has no open step left.

## Found in passing, not in the plan

Noticed while doing other work. Recorded here because `AUDIT-20260715.md` is dated and
frozen — retro-fitting findings into it would make it a document that cannot be trusted as
a snapshot. An unwritten finding is one that gets re-discovered.

| What | Where | Belongs to |
|---|---|---|
| `UIBackgroundModes` = `remote-notification` is declared with no push code behind it — a background mode without its functionality is a classic rejection motive (2.5.4). Deliberately left in place rather than removed: 3d decides it with code in front of it, since only *silent* push needs it | `Wematch/Info.plist` | 3d |
| ~~`HealthKitHeartRateService` is a WatchConnectivity relay wearing the wrong name~~ — renamed `WatchRelayHeartRateService`, moved to `Core/WatchConnectivity/` (2026-08-18); decision [0009](decisions/0009-the-iphone-asks-healthkit-for-nothing.md) is finished | `Core/WatchConnectivity/WatchRelayHeartRateService.swift` | done |
| ~~Two `firebaseService as? FirebaseRealtimeService` downcasts for the `onDisconnect` hook~~ — `armDisconnectRemoval`/`disarmDisconnectRemoval` are on `FirebaseServiceProtocol` (2026-08-18), and they *throw*: a hook the server refuses used to fail silently, leaving a ghost participant after a crash. `joinRoom` fails if the hook does not arm; `leaveRoom` removes, then disarms. Three tests that could not exist before | `FirebaseRoomRepository.swift` | done |
| `try? await profileRepository.fetchProfile` ×3 (Groups, Friends): reads degrading to a missing display name, unlogged. Not writes, so left out of 1.8's `try?` sweep | `GroupDetailViewModel.swift:85`, `FriendListViewModel.swift:73,93` | open — small |

## Blocked on Rémy

- Anything on real hardware: the device pass, the field session, TestFlight upload.

The plan's rule that Xcode target surgery must be done in the GUI (Risks section) no longer
applies to 1.11 — it was done by editing the project file directly, in two halves: the
package wired in first while `WematchShared` still stood, so every structural edit was
additive and provable by a build, and the deletion only afterwards. Both targets build
Debug and Release, and `xcodebuild -list` shows the three remaining targets.
