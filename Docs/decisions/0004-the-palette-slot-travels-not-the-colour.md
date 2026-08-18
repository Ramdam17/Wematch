# 0004 — The palette slot travels on the wire, never a resolved colour

**Date:** 2026-07-27 · **Plan step:** 2.2 · **Status:** accepted

## Context

Participants need the same heart colour on every device in the room, and on the Watch. The
straightforward move is to resolve the colour where the participant is created and send the
hex along with the heart rate.

## Decision

Only the palette **slot index** crosses a process boundary — Firebase, WatchConnectivity,
the dashboard records. Each renderer resolves the slot to a colour locally.

## Why

A hex on the wire freezes the palette at the moment it was written: re-deriving the palette
would leave old records and remote devices showing colours that no longer exist. It also
resolves against the *sender's* appearance, which need not be the receiver's.

Slots are derived from the user ID by **FNV-1a over UTF-8** of the `firebaseSafe` form.
Never `hashValue`: Swift seeds `Hasher` randomly per process, so a user drew a new colour on
every launch and two devices never agreed.

## Evidence

`c1c08b6`. `WatchHeartPalette` duplicates the derivation for the Watch target, because
`WematchShared` is iOS-only.

## Consequences

The two implementations of the slot function must be kept in step by hand until plan step
1.11 turns `WematchShared` into a multiplatform package. Field-test case S1 checks the
cross-device agreement this decision exists to guarantee.
