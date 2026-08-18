# TestFlight Setup

Plan step 2.4. One-time distribution setup, plus the gate every build must pass before it
leaves the Mac.

## The gate

Nothing is distributed — TestFlight included — before plan steps 1.1–1.3 are done.

| # | What | State |
|---|------|-------|
| 1.1 | Firebase Auth + RTDB security rules, versioned in `firebase/` | Done — `a28d57e`, `9ffe0dc` |
| 1.2 | Social graph on Firestore with per-user rules; dead CloudKit layer purged | Done — `1239b77`, `41a4ddb` |
| 1.3 | `PrivacyInfo.xcprivacy`, Keychain ACL, `.private` HR logs | Done — `8087f5b` |

Per build, also true before upload:

- [ ] `xcodebuild test -scheme Wematch` green (151 tests as of `ef8d5bf`)
- [ ] Both targets build for a **device** destination, not just the simulator
- [ ] `Wematch/Resources/GoogleService-Info.plist` is the real one (it is gitignored, so CI
      builds with a placeholder and **cannot** produce a shippable archive — archive locally)
- [ ] The RTDB rules deployed to the project match `firebase/database.rules.json`

## Project facts

| | |
|---|---|
| Team | `TFK566BG76` |
| iPhone bundle ID | `com.remyramadour.Wematch` |
| Watch bundle ID | `com.remyramadour.Wematch.watchkitapp` (companion wired via `WKCompanionAppBundleIdentifier`) |
| Version / build | `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1` |
| Signing | Automatic |

The Watch app is embedded in the iPhone app: archiving the `Wematch` scheme ships both.
There is no separate Watch upload.

## Decisions before the first upload

Each costs one line. The first is done; the other two are still open.

1. ~~**`WKBackgroundModes` = `workout-processing` on the Watch target.**~~ **Done** — the
   Watch target now has its own `Info.plist` carrying the array, verified in the shipped
   bundle. Without it a `HKWorkoutSession` runs only while the app is in the foreground.
2. **Export compliance.** `ITSAppUsesNonExemptEncryption` is not set, so App Store Connect
   asks the question on every upload. Wematch uses only standard TLS (Firebase), the
   ordinary exemption. Setting `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` retires
   the prompt.
3. **Dead capabilities.** `Wematch.entitlements` still carries `icloud-services: CloudKit`
   and `healthkit.background-delivery`. The CloudKit layer was purged in 1.2d and the
   iPhone never queries HealthKit directly — HR arrives over WatchConnectivity. Both are
   unused capability surface on a build handed to colleagues. Already on the plan as
   finding **F6** (sprint 3b, "remove unused entitlements") — worth pulling forward if the
   build is going to colleagues first.

## Archive and upload

```bash
# 1. Archive (device destination; the Watch app rides along)
xcodebuild archive \
  -scheme Wematch \
  -destination 'generic/platform=iOS' \
  -archivePath ~/Desktop/Wematch.xcarchive

# 2. Export for App Store Connect
xcodebuild -exportArchive \
  -archivePath ~/Desktop/Wematch.xcarchive \
  -exportOptionsPlist Docs/field-tests/ExportOptions.plist \
  -exportPath ~/Desktop/Wematch-export
```

`ExportOptions.plist` is committed next to this file — it holds nothing secret, only the
team ID that is already in the project file and the distribution method. Older Xcode used
`app-store` for `method`; if the export rejects the value, that is the one to try.

For the upload itself, use **Xcode → Organizer → Distribute App**. A CLI upload exists
(`xcrun altool --upload-app`) but its support status has moved around across Xcode
releases — check `xcrun altool --help` before relying on it in a script.

## App Store Connect, first time only

- [ ] Create the app record: bundle ID `com.remyramadour.Wematch`, SKU, primary language
- [ ] Answer the **health data** questions — the app reads heart rate and shares it, in real
      time, with other people in the room. Say so plainly; it is the point of the app
- [ ] Privacy nutrition label: heart rate (health & fitness), user ID, linked to identity,
      used for app functionality, not for tracking
- [ ] TestFlight → Internal Testing group → add your colleagues by Apple ID
- [ ] Build processing takes a few minutes; internal testers need no review

## After the session

Testers install from TestFlight, both the iPhone app and — from the Watch app on the phone
— the Watch app. Confirm on each device that the Watch app is actually installed before
starting: the script's first case fails confusingly otherwise.
