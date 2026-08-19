# 0009 — The iPhone asks HealthKit for nothing

**Date:** 2026-08-18 · **Plan step:** 1.7 (found in passing, decided here) · **Status:** accepted

## Context

`RoomViewModel.enterRoom` requested HealthKit read authorization on the phone, and the
iPhone target carried `com.apple.developer.healthkit` plus two usage strings. The phone
performs no HealthKit query: `HealthKitHeartRateService.startHeartRateStreaming()` returns
an empty stream that `yield(heartRate:)` fills from WatchConnectivity. Its own comment said
so. The refusal branch raised `RoomError.healthKitDenied` for a case that cannot occur —
`requestAuthorization` returns normally whether the user allows or denies, and throws only
on system errors (WWDC20-10664). The prompt was therefore a question asked for nothing,
and the entitlement a declared capability with no code behind it.

## Decision

Removed from the **iPhone target only**: the `com.apple.developer.healthkit` entitlement,
`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`, the
`requestAuthorization()` call, `RoomError.healthKitDenied`, and the now-unused
`requestAuthorization`/`isAuthorized` members of `HealthKitServiceProtocol`.

The **Watch target is untouched**: it keeps its own entitlements file, both usage strings
and `WKBackgroundModes = workout-processing`. Entitlements are per binary.

## Why

The rejected option was keeping the entitlement "for later" — an iOS-only mode, or reading
historical heart rate for the dashboard. It was rejected on the same grounds already
recorded for `UIBackgroundModes = remote-notification`: a declared capability with no
functionality is a classic review rejection, and Apple does not accept intent as
justification. If the phone ever needs to read HealthKit, the entitlement and the call come
back together — that is one commit, not a reason to ship an unused permission prompt to
every user before their first room.

Keeping the entitlement while dropping the call, or the reverse, were both worse than
either extreme: the first declares a capability with nothing behind it, the second asks
for an authorization the entitlement no longer permits, which is the one configuration
where `requestAuthorization` *does* throw.

## Evidence

Verified in the **built** bundle, not the sources — the pbxproj accepts settings it then
drops (see the `INFOPLIST_KEY_WK*` gotcha in `CLAUDE.md`):

```
Wematch.app.xcent          → application-identifier, com.apple.developer.applesignin
Wematch.app/Info.plist     → no NSHealth* key
Watch App.app-Simulated.xcent → com.apple.developer.healthkit = true
Watch App.app/Info.plist   → NSHealthShareUsageDescription, NSHealthUpdateUsageDescription,
                             WKBackgroundModes = [workout-processing]
```

195 tests pass, `swiftlint --strict` clean, both targets build.

**What is NOT evidence yet:** that the Watch still obtains its HealthKit authorization with
the phone's entitlement gone. Entitlements are per binary and a watchOS app has owned its
own authorization since watchOS 2, so this is expected to hold — but no Wematch build has
ever run on a Watch, so it is knowledge, not a measurement. Field-test case S2 is where it
is checked, and it is the first case in the script: if this decision is wrong, the session
says so in its first minute.

## Consequences

`HealthKitHeartRateService` no longer touches HealthKit — it is a WatchConnectivity relay
wearing the wrong name. `WatchRelayHeartRateService` is what it should be called; the rename
was left out of this change and is not cosmetic tidying, it is finishing this decision.

The dead `RoomError.healthKitDenied` is gone, so nothing in the room now claims a heart-rate
permission problem the phone could never have detected. The one thing that *can* detect it
is the Watch, and it says so through `WatchHeartRateStatus` (see plan 1.7).

Do not re-add the entitlement to make a HealthKit API "available" — availability is not the
problem, and the phone has no query to run.
