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

Two backends: RTDB for ephemeral heart rate, Firestore for the persistent graph. The
entitlements file still carries `icloud-services: CloudKit` — dead, and flagged for removal
in `Docs/field-tests/testflight-setup.md`.
