# Firebase configuration (plan 1.1, audit B2/A5)

Security rules for the Realtime Database are versioned here and deployed via CLI —
never edited in the Firebase console directly.

```bash
npx firebase-tools deploy --only database        # deploy rules
npx firebase-tools emulators:start               # local auth + database emulators
```

## Access model (v1 — colleagues only)

Everything requires **Firebase Authentication** (Sign in with Apple, federated). Path keys
are **Firebase Auth UIDs** (`auth.uid`), NOT firebaseSafe(appleUserID) — no more ID
mangling in paths (see audit E1).

| Path | Read | Write |
|---|---|---|
| `rooms/$roomID` | any authenticated user | — |
| `rooms/$roomID/metadata` | (inherited) | any authenticated user |
| `rooms/$roomID/users/$uid` | (inherited) | only `auth.uid == $uid`, schema-validated (HR 0–250, no extra fields) |
| `tempRooms/$uid` | only owner | any authenticated user (both participants maintain each other's index) |
| everything else | denied | denied |

## Known limitations (accepted for v1, hardening backlog)

- **Room reads are app-wide, not member-scoped**: any signed-in user who learns a roomID
  can observe HR positions in it. Acceptable for a colleagues-only TestFlight; fix by
  maintaining `rooms/$roomID/members/$uid` and gating `.read` on it (Phase 3+).
- **`tempRooms/$uid` is writable by any authenticated user** because room creation and
  deletion write the peer's index entry. Tightening requires restructuring the index
  (e.g. invites subtree written by sender, index written by owner only).
- **`metadata` writes are not admin-scoped** — same v1 trade-off.

Every relaxation above still represents a step change from the previous state
(NO authentication, NO rules at all).

## Firestore (social graph — plan 1.2, decision 2026-07-16)

The social graph (profiles, groups, friends, inbox) migrates from CloudKit public DB to
Firestore under the same Firebase Auth (rationale: `Docs/plans/spike-20260716-cloudkit-sharing.md`).
Rules: `firebase/firestore.rules`. Key property CloudKit could not express: **recipient
semantics** — anyone signed-in can deliver into `inbox/{uid}/messages`, only `{uid}` can
read/update/delete. v1 trade-offs (documented inline): `users/` and `groups/` are readable
app-wide (username search + join-by-code); membership updates are coarse-grained
(member may touch `memberIDs` only).

```bash
npx firebase-tools deploy --only firestore:rules
npx firebase-tools emulators:start                # auth + database + firestore
```
