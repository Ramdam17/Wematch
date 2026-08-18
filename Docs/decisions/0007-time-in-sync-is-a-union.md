# 0007 — Time in sync is a union of intervals, not a sum

**Date:** 2026-07-27 · **Plan step:** 2.2 · **Status:** accepted

## Context

The dashboard reports how long the user spent synchronised. A room can hold several sync
partners at once, so at any instant the user may be inside several `SyncEvent`s.

## Decision

`DashboardMetrics.connectedDuration` merges overlapping and touching intervals and sums the
merged stretches. The plain sum survives as `totalSyncDuration`, labelled as such.

## Why

Summing per-partner durations counts the same second once per partner. In a five-person
cluster, ten minutes in the room can report fifty minutes "in sync" — a number the user can
disprove by looking at a clock, which discredits every other number on the screen.

The two are different questions and both are kept: the union answers "how much of my time
was spent connected to someone", the sum answers "how much partner-time did I accumulate".

## Evidence

A test asserts that the sum can exceed total room time while the union cannot. Intervals
that merely touch are merged: `SyncSessionRecorder` closes one event and opens the next at
the same instant when the cluster changes, so touching ranges are one unbroken stretch, not
two.

## Consequences

The Watch shows the union, and formats it with its own duplicated implementation
(`WatchDashboardSnapshot.connectedDurationText`). The two implementations are held together
by a table in `DashboardViewModelTests` — change both at once.
