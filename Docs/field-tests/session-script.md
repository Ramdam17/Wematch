# Session Script — 2 people, 2 Watches

Plan step 2.4. Roughly 45 minutes. Work through the cases in order; later ones assume the
earlier ones ran.

**Roles.** **A** = you, running the session and holding the log. **B** = your colleague.
Both need an iPhone with the TestFlight build, an Apple Watch with the Watch app installed,
and a signed-in account.

**Marks.** **Expect** — the code determines this; a deviation is a defect, open it against
the quoted plan step. **Measure** — the code does *not* determine this; there is no correct
answer yet, write the number down.

**Before you start**

- [ ] Both phones on the same build; note the build number and commit SHA in the log
- [ ] Watch app present on both Watches (Watch app on iPhone → My Watch → Wematch)
- [ ] Battery % noted for all four devices
- [ ] Firebase console open on A's laptop: Realtime Database → `rooms/`
- [ ] Stopwatch ready — half these cases are latencies

---

## S0 — Cold start and pairing

1. Force-quit both apps on both phones and both Watches.
2. Launch the iPhone app on A. Watch A's wrist.

**Expect** — the Watch app wakes on its own (the phone sends `appLaunched` at launch) and
shows the **Idle** screen: a still screen naming the app, no plot, no fake data.
**Expect** — the Watch does *not* start a workout. No workout indicator in the status area.
**Measure** — seconds from iPhone launch to the Watch app being awake.

Repeat on B.

---

## S1 — Join

1. A opens a room. B joins the same room.

**Expect** — first entry prompts for HealthKit on the phone *and* on the Watch. Grant both.
**Expect** — the Watch leaves Idle for the waiting screen, then the plot, and a workout
starts (the workout indicator appears).
**Expect** — Firebase console: `rooms/{roomID}/users/` has exactly two children, keyed on the
`firebaseSafe` user IDs (dots replaced by underscores).
**Expect** — **each person's heart is the same colour on both phones.** The palette slot is
derived from the user ID by FNV-1a, precisely so two devices agree. If A is pink on A's phone
and green on B's, the slot derivation is broken — that is a defect, not a rendering
difference.
**Measure** — seconds from B tapping join to B's heart appearing on A's plot.
**Measure** — how far the two hearts sit apart at rest, in BPM.

---

## S2 — Wrist down (the workout-processing probe)

Run this early: if it fails, everything after it is measuring the wrong thing.

1. Both stay in the room. B lowers their arm and holds still for 60 seconds, screen off.
2. A watches B's heart on A's plot.

**Measure** — does B's heart keep updating, or freeze? Note the seconds until the first
freeze, and whether it resumes when B raises their wrist.

Context: the Watch target declares `WKBackgroundModes` = `workout-processing`, which is
what lets a `HKWorkoutSession` keep running outside the foreground. That was verified in the
built bundle, never on a wrist — this case is the first real test of it. A freeze here means
the capability is not doing what the documentation says it does, which changes the design of
the Watch app, not just a setting.

---

## S3 — Sync

1. Both sit still and breathe slowly together, or one walks in place, until the two hearts
   converge. Synchrony is Euclidean distance ≤ **5 BPM** in (previous HR, current HR) space
   — both coordinates must be close, so a crossing counts only if the *trend* matches too.

**Expect** — on the frame the edge forms: stars appear, a haptic fires on the phone and on
the Watch, the HUD chain count reads 2.
**Expect** — stars spawn on **new** edges only. A steady sync should not pour stars
continuously; if it does, the edge-diffing regressed.
**Expect** — never more than **24** stars on screen at once (F4 cap). Stars begin fading at
2.5 minutes and vanish at 3.
**Expect** — a cluster circle is drawn around the pair.
**Measure** — do both Watches buzz at the same moment, or does one lag? By how much?
**Measure** — how hard was it to reach sync? Seconds of trying. This is the product question
the whole app rests on.

---

## S4 — Leave, the intended way

1. A taps **Leave** in the toolbar.

**Expect** — a native confirmation dialog: "Leave this room?".
**Expect** — on confirm: A's Watch stops its workout (indicator gone) and returns to Idle.
**Expect** — A's node disappears from `rooms/{roomID}/users/` in the console.
**Expect** — on B's plot, A's heart and the cluster circle disappear; the participant count
drops to 1.
**Expect** — A's Settings → Dashboard now shows one more session, and a non-zero "Time in
sync" if S3 worked.
**Measure** — seconds between A confirming and A's heart leaving B's screen.

---

## S5 — Leave by swiping back (audit C1)

1. A re-joins. Once the plot is up, A swipes from the left edge to go back, rather than
   using the Leave button.

**Expect** — identical teardown to S4: workout stopped, Firebase node gone, tasks cancelled.
This is the path audit finding C1 was about and plan step 1.4 fixed by moving teardown to
`onDisappear`; the button is not the only way out.
**Measure** — anything that differs from S4, however small.

---

## S6 — Phone in the background

1. Both re-join. A presses the Home button and waits 60 seconds, then returns.

**Expect** — the animated background is paused while backgrounded (plan 1.6, F3): coming
back should not show a frantic catch-up animation.
**Measure** — what B sees during those 60 seconds: does A's heart keep moving, freeze, or
disappear?
**Measure** — on A's return, does the plot recover on its own, and after how long?
**Measure** — A's battery drop over the whole session so far.

---

## S7 — Kill the iPhone app mid-room

This case has a known, unpleasant answer. Run it anyway and record the numbers.

1. Both in the room. A force-quits the iPhone app from the app switcher.

**Expect** — A's Watch **stays in the room and keeps its workout running**. Nothing tells it
otherwise: `onDisappear` never runs on a kill, so no `exitRoom` message is ever sent. The
only way out is the **Stop** button on the Watch itself.
**Expect** — A's session is **missing from A's Dashboard**: the records are written on the
way out of the room, and there was no way out.
**Measure** — seconds until A's heart disappears from B's plot. This is Firebase's
`onDisconnect` reaping the node, and nobody has measured how long it takes.
**Measure** — how long A's Watch keeps streaming before you stop it, and the battery cost.

Then: press **Stop** on A's Watch and confirm the workout ends.

---

## S8 — Airplane mode

1. Both re-join. A enables airplane mode and waits 90 seconds, then disables it.

**Expect** — no connection banner or offline state appears. There is no connection-state
indicator yet (plan 1.7, finding D3); the plot simply keeps showing the last values it had.
Do not file this — record how misleading it is, which is the argument for 1.7's priority.
**Measure** — seconds until A's heart is reaped from B's plot.
**Measure** — on airplane mode off: does A rejoin on their own? Does A's heart return to B's
plot without A doing anything? The code does not re-join; whether the RTDB SDK's queued
writes restore presence is an open question, and this is the case that answers it.
**Measure** — anything logged as an error, visible or not.

---

## S9 — Watch out of range

1. Both re-join. B leaves the phone on the table and walks away with the Watch until they
   are out of Bluetooth range (or force-quits the Watch app — same effect from the phone's
   side).

**Expect** — B's heart freezes on the plot at its last value and stays there. There is no
staleness detection: on a real device the phone's HR *comes from* the Watch, so losing the
Watch stops the updates without removing the participant.
**Measure** — how long a stale heart stays on the plot before anything changes.
**Measure** — on B's return: does streaming resume by itself?

---

## S10 — One-to-one temporary room

1. A opens a temporary room with B from the Friends tab; B accepts.

**Expect** — the same room ID on both sides regardless of who created it (it is derived,
`temp_{sorted safe A}_{sorted safe B}`).
**Expect** — when the last of the two leaves, the room *and* its index under
`/tempRooms/{userID}/` are gone from the console. Check both sides' indexes.
**Measure** — anything left behind in the console after both leave.

---

## S11 — Theme and VoiceOver, on real hardware

1. A: Settings → theme picker → switch between **Pastel** and **Cosmic**, then back to
   **System**.

**Expect** — the whole app follows immediately, the room plot included. The plot's colours
come from dynamic `UIColor`s resolved against the trait collection, which was only ever
verified in the simulator — this is the device confirmation.
**Expect** — with the phone set to System, flipping iOS's own appearance flips the app.

2. A: turn on VoiceOver and swipe through the room HUD.

**Expect** — the HUD reads as whole facts ("Heart rate, 72 BPM"), not as loose fragments.
**Measure** — anything unreadable, out of order, or silent.

---

## S12 — Does the Dashboard tell the truth?

Last, with the session's memory still fresh.

1. A opens Settings → Dashboard.

**Expect** — "Best friend" is B, with B's own heart colour.
**Expect** — "Time in sync" is at most the total time spent in rooms. It is a union of
overlapping sync intervals, not a sum, so it cannot exceed the wall-clock time in the room.
If it does, the union broke.
**Expect** — "Stars made" matches roughly what you watched happen, not the number of sync
events.
**Expect** — the session killed in S7 is absent. Sessions are recorded on the way out.
**Measure** — every number, against your memory of the session. This screen has never been
compared to a real session.

---

## Known gaps — do not file these

Already on the plan; note them if they bite, but they are not new.

| What you will see | Why | Plan step |
|---|---|---|
| No offline / connection indicator | Not built | 1.7 (D3) |
| An error path showing an empty room instead of an error | Not built | 1.7 (D1, D2) |
| A crash during HR streaming | Two `@unchecked Sendable` types are known-unsafe under real streaming | 1.10 (C3) |
| The Watch keeping a workout after the phone dies | No Watch-side watchdog; the Stop button is the mitigation | — |

## What to capture

- Build number and commit SHA
- Both phone models and iOS versions; both Watch models and watchOS versions
- Screenshots of anything surprising, from both sides — one side's screenshot never shows a
  sync disagreement
- Firebase console screenshots for S1, S7, S8, S10
- Any crash: Settings → Privacy & Security → Analytics & Improvements → Analytics Data,
  find `Wematch-*.ips`, and share it to the Mac
- Battery % for all four devices, before and after
