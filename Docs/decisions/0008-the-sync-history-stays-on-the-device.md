# 0008 — The sync history never leaves the device

**Date:** 2026-07-27 · **Plan step:** 2.2 · **Status:** accepted

## Context

The dashboard needed a producer: nothing had ever written a `SessionLog` or a `SyncEvent`,
so the Sprint-12 models had no data behind them. Deciding to record raised the question of
where the records live — the app already has two backends.

## Decision

Records are written to a JSON file in Application Support, with
`[.atomic, .completeFileProtection]`. Nothing is uploaded. `AccountDeletionService` erases
the file as part of deletion.

## Why

The history is a log of when this person's heart matched another named person's, minute by
minute. That is the most intimate data the app produces, and it is the only data with no
functional reason to be shared — the room already broadcasts what the room needs, live.
Keeping it local means it cannot leak from a backend that was, three weeks ago, world
readable (audit B1/B2).

`completeFileProtection` because an unlocked-device requirement costs nothing here: the
dashboard is only read when the user is looking at it.

## Consequences

The history does not follow the user to a new phone, and there is no backup. That is the
accepted price; if it is ever revisited, the decision to revisit is a new file, not an edit
to this one. Tests must inject `DashboardRecordStoring` — `InMemoryDashboardRecordStore`
exists for that — or they write into the test host's real Application Support directory.
