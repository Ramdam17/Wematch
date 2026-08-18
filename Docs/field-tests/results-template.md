# Field Session — YYYY-MM-DD

Copy to `YYYYMMDD-2p-<label>.md` and fill in as you go. Leave a case blank only if it was
not run, and say why — a blank that looks like a pass is worse than a gap.

## Setup

| | A | B |
|---|---|---|
| Person | Rémy | |
| iPhone / iOS | | |
| Watch / watchOS | | |
| Battery before / after | / | / |

- Build number:
- Commit SHA:
- Date and duration:

## Results

| Case | Ran | Outcome | Numbers |
|------|-----|---------|---------|
| S0 Cold start and pairing | ☐ | | wake: _s |
| S1 Join | ☐ | | join→visible: _s · resting gap: _ BPM |
| S2 Wrist down | ☐ | | freeze after: _s · resumed: ☐ |
| S3 Sync | ☐ | | haptic skew: _s · time to first sync: _s |
| S4 Leave (button) | ☐ | | leave→gone on B: _s |
| S5 Leave (swipe back) | ☐ | | differences vs S4: |
| S6 Phone backgrounded | ☐ | | B saw: · recovery: _s |
| S7 Kill the app | ☐ | | reap delay: _s · Watch ran on for: _min |
| S8 Airplane mode | ☐ | | reap delay: _s · rejoined alone: ☐ |
| S9 Watch out of range | ☐ | | stale heart persisted: _s · resumed: ☐ |
| S10 Temporary room | ☐ | | leftovers: |
| S11 Theme and VoiceOver | ☐ | | |
| S12 Dashboard truth | ☐ | | |

## Defects found

One per row. A defect is a deviation from an **Expect**, or anything that made the app
unusable regardless of what the script predicted.

| # | Case | What happened | Finding / plan step | Severity |
|---|------|---------------|---------------------|----------|
| 1 | | | | |

## Measurements worth keeping

Numbers that had no expected value and now have a first data point — reap delays, latencies,
battery cost. These become thresholds later.

## What the session felt like

Two or three sentences, written the same day. Was reaching sync fun or tedious? Did the room
feel alive or static? Did B understand what they were looking at without being told? The
audit can be closed by tests; this question cannot, and it is the one that decides whether
the app is worth finishing.
