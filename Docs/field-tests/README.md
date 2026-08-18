# Field Tests

Plan step 2.4. This directory holds the protocol for running Wematch against reality, and
the log of every session actually run.

The audit's central finding is that fourteen sprints shipped without the app ever meeting a
second person, a second Watch, or a bad network. Unit tests cannot close that: the sync
graph is provable in a test, but "does B see A's heart, and how long after A walks into a
lift" is not. **Phase 2 does not exit until one real two-person session is logged here.**

## Contents

| File | What it is |
|------|-----------|
| `testflight-setup.md` | One-time distribution setup, plus the gate that must be green before any build leaves the Mac |
| `session-script.md` | The two-person / two-Watch script: join, sync, leave, kill, airplane, out-of-range |
| `results-template.md` | Copy this per session |

## Running a session

1. Check the gate in `testflight-setup.md`. Nothing is distributed before plan steps
   1.1–1.3 are done — they are, as of `8087f5b`, but re-read the gate anyway: it also
   covers what must be true of *this* build.
2. Copy `results-template.md` to `YYYYMMDD-2p-<label>.md` (e.g. `20260820-2p-first.md`).
3. Work through `session-script.md` in order and fill the log as you go.
4. Commit the log. A session that was run but not written down did not happen — that is
   the whole reason this directory exists.

## Reading a result

Each case is marked **Expect** or **Measure**.

- **Expect** — the code determines the outcome. A deviation is a defect: open it against
  the plan with the finding ID quoted in the case.
- **Measure** — the code does *not* determine the outcome. There is no right answer yet;
  write the number down. These are the cases that will set thresholds later (reap delay,
  reconnection behaviour, battery cost).

Do not file the entries under "Known gaps" as new defects. They are already on the plan.
