# 0001 — Firestore replaces private CloudKit + CKShare for the social graph

**Date:** 2026-07-16 · **Plan step:** 1.2 · **Status:** accepted

## Context

Audit finding B1: any signed-in user could query another user's social data. The fix
required a real access model. The candidate was CloudKit's private database with `CKShare`
per relationship, keeping the existing repository layer.

## Decision

The social graph — profiles, groups, friends, inbox — moves to Firestore, under the same
Firebase Auth introduced for the RTDB in 1.1. The CloudKit layer is deleted, not kept as a
fallback.

## Why

Three facts closed the CloudKit path, all documentary — the two-account spike was never
run because it no longer needed to be:

- the inbox-write pattern needs a shared zone per relationship, not per user;
- user discoverability is deprecated with no replacement, so share URLs must travel outside
  CloudKit anyway — the architecture ends up hybrid whatever we do;
- shared-database notifications are reported unreliable in production.

Firestore under the Auth we already had gives recipient semantics natively.

## Evidence

`Docs/plans/spike-20260716-cloudkit-sharing.md`. Rules are versioned in `firebase/` and
covered by emulator tests (`7fc01be`).

## Consequences

Two backends: RTDB for ephemeral heart rate, Firestore for the persistent graph. ~~The
entitlements file still carries `icloud-services: CloudKit` — dead, and flagged for removal
in `Docs/field-tests/testflight-setup.md`.~~ *(Removed 2026-08-17; the entitlements now
carry only Sign in with Apple and HealthKit.)*

**Added 2026-08-18 — what this decision retired without saying so (audit D4, plan 1.8).**
D4 was a read-modify-write race: two clients each reading `Group.memberIDs`, appending,
and writing the array back, the second silently erasing the first — with the CloudKit fix
being a `serverRecordChanged` retry loop. On Firestore no client writes that array at all:
membership goes through `FieldValue.arrayUnion`/`arrayRemove` in a batch, and friend
acceptance is one batch — the merge happens on the server, and there is nothing to retry.
The atomicity was a consequence of this decision, not a reason for it, and it is recorded
here so that D4 is not re-discovered. Uniqueness (usernames, group codes) is the same
idea by reservation document: a claim can only *create*, so two claimants cannot both win.
