# Wematch — Sprint Plan

> **Version:** 1.0
> **Date:** February 11, 2026
> **Methodology:** Feature-based sprints, one Git branch per sprint
> **Branch naming:** `sprint/XX-short-description`
> **Merge policy:** Only with explicit approval from project owner

---

## Sprint Overview

| Sprint | Name | Core Deliverable | Branch |
|--------|------|-----------------|--------|
| 0 | Foundation | Project structure, design system, architecture | `sprint/00-foundation` |
| 1 | Authentication | Sign in with Apple + username generation | `sprint/01-authentication` |
| 2 | Groups | CloudKit group CRUD + search | `sprint/02-groups` |
| 3 | Friends | Friend system + username search | `sprint/03-friends` |
| 4 | Inbox | In-app notification system | `sprint/04-inbox` |
| 5 | Heart Rate Pipeline | HealthKit + WatchConnectivity + Firebase | `sprint/05-heart-rate` |
| 6 | Room Animation | 2D plot, Bézier movement, heart rendering | `sprint/06-room-animation` |
| 7 | Sync & Clusters | Sync detection, graph algorithms, cluster display | `sprint/07-sync-clusters` |
| 8 | Sync Effects | Circles, stars, haptics | `sprint/08-sync-effects` |
| 9 | Apple Watch | Watch app with simplified room | `sprint/09-watch-app` |
| 10 | Temporary Rooms | 1-on-1 friend rooms | `sprint/10-temp-rooms` |
| 11 | Settings & Account | Logout, data deletion | `sprint/11-settings` |
| 12 | Dashboard Stubs | Placeholder UI + data models | `sprint/12-dashboard-stubs` |
| 13 | Polish & QA | Design refinement, performance, accessibility | `sprint/13-polish` |

---

## Sprint 0 — Foundation

**Goal:** Establish project structure, shared design system, and architectural scaffolding. No functional features yet.

### Pre-existing Project State

The Xcode project "Wematch" already exists with a basic iPhone target. The following has been configured:
- HealthKit capability with Background Delivery enabled
- Face ID capability (⚠️ to be **removed** — not used in v1)
- Background Modes capability (nothing checked yet)

The following is **missing** and must be added:
- Apple Watch companion app target
- Sign in with Apple capability
- CloudKit capability (container)
- WatchConnectivity integration points
- Shared framework target

### Deliverables

**Project structure & targets:**
- [ ] **Remove Face ID capability** from iPhone target (not used)
- [ ] **Add Apple Watch target** (watchOS 26+) as companion app
- [ ] **Add shared framework target** (`WematchShared`) for code shared between iPhone and Watch
- [ ] Configure Watch target with HealthKit capability (workout session for HR)
- [ ] Add **Sign in with Apple** capability to iPhone target
- [ ] Add **CloudKit** capability to iPhone target (configure container ID)
- [ ] Configure Background Modes: check "Remote notifications" (for CloudKit subscriptions) and "External accessory communication" if needed
- [ ] Verify HealthKit entitlements: Health Update usage description already present, ensure HR read type is specified

**Architecture scaffolding:**
- [ ] SwiftUI app entry point with TabView (Rooms / Groups / Friends / Inbox)
- [ ] Navigation structure with placeholder views for each tab
- [ ] MVVM folder structure as defined in CLAUDE.md (Core/, Features/, Shared/, Resources/)
- [ ] Watch app entry point with placeholder view
- [ ] WatchConnectivity session setup (both sides, no data flow yet)

**Design system:**
- [ ] Color palette (pastel light rainbow unicorn — curated gradient stops)
- [ ] Typography scale (SF Pro / SF Rounded)
- [ ] Reusable Liquid Glass card component (`GlassCard`)
- [ ] Reusable gradient button component (`GradientButton`)
- [ ] Badge/pill component (`StatusBadge`)
- [ ] Animated gradient background with floating particles (`AnimatedBackground`)
- [ ] Heart icon component (`HeartIcon` — glassmorphic 3D heart with inner glow)

**Infrastructure:**
- [ ] Firebase SDK integration (Realtime Database, configured but no data flow)
- [ ] CloudKit container configured (entitlements, container ID)
- [ ] Feature flag system:
  - [ ] `FeatureFlag` protocol with `isEnabled(feature:) -> Bool`
  - [ ] `LocalFeatureFlagProvider` implementation (all features enabled in v1)
  - [ ] Feature enum covering all gatable features (room access, group creation limits, friend list size, dashboard access, etc.)
  - [ ] Injected via `@Environment` for easy swap to remote config later
- [ ] Service layer protocol abstractions (CloudKit, Firebase, HealthKit, WatchConnectivity)
- [ ] Repository pattern templates for each feature domain
- [ ] Shared models directory structure
- [ ] `README.md` for the repo

### Acceptance Tests

| # | Test | Pass Criteria |
|---|------|--------------|
| 0.1 | App launches on iOS 26 simulator | Tab bar visible with 4 tabs, each shows a placeholder |
| 0.2 | Design system components render | Card, button, badge, and background all display correctly in a preview |
| 0.3 | Watch app launches | Watch companion app compiles and runs on watchOS 26 simulator |
| 0.4 | Watch ↔ iPhone connectivity | WCSession activates on both sides (logged, no data transfer yet) |
| 0.5 | Firebase initializes | `FirebaseApp.configure()` succeeds without crash |
| 0.6 | CloudKit container accessible | `CKContainer.default()` returns configured container |
| 0.7 | Feature flags all enabled | `LocalFeatureFlagProvider.isEnabled(.roomAccess)` returns `true` for all features |
| 0.8 | Services behind protocols | All service managers conform to protocols, no direct CloudKit/Firebase imports in Views or ViewModels |
| 0.9 | Face ID capability removed | No Face ID entry in Signing & Capabilities |
| 0.10 | Sign in with Apple capability present | Capability visible in Signing & Capabilities |
| 0.11 | Three targets exist | iPhone app, Watch app, and Shared framework all compile |

---

## Sprint 1 — Authentication

**Goal:** User can sign in with Apple and get a unique username.

### Deliverables

- [ ] Sign in with Apple button (full screen, matching mockup design)
- [ ] Authentication flow using `AuthenticationServices`
- [ ] On first sign-in:
  - [ ] Generate random username (`{adjective}_{animal}{NNNN}`)
  - [ ] Check uniqueness against CloudKit
  - [ ] Present username with shuffle button
  - [ ] User confirms → create CloudKit user profile
- [ ] Session persistence (user stays logged in until explicit logout)
- [ ] Auth state management (global `@Observable` or `@EnvironmentObject`)
- [ ] Username dictionaries: ~100 adjectives, ~100 animals (embedded in app)
- [ ] "Your data is safe & private" label on sign-in screen

### Acceptance Tests

| # | Test | Pass Criteria |
|---|------|--------------|
| 1.1 | Sign in with Apple succeeds | User taps button, Apple sheet appears, auth completes |
| 1.2 | Username is generated | After sign-in, a username matching `{adj}_{animal}{0000-9999}` pattern is displayed |
| 1.3 | Shuffle generates new username | Tapping shuffle produces a different username each time |
| 1.4 | Username uniqueness | Two users cannot have the same username (test with CloudKit) |
| 1.5 | Profile persists in CloudKit | After sign-in, a `UserProfile` record exists in CloudKit |
| 1.6 | Session persists | Kill and relaunch app → user is still signed in, tab bar visible |
| 1.7 | No FaceID prompt | At no point during or after sign-in is FaceID requested |

### Unit Tests

- `UsernameGenerator` produces valid format
- `UsernameGenerator` never produces empty components
- Adjective and animal dictionaries have ≥ 100 entries each
- CloudKit uniqueness check returns `true` for unused username
- CloudKit uniqueness check returns `false` for existing username

---

## Sprint 2 — Groups

**Goal:** Users can create, search, join (with approval), and manage groups.

### Deliverables

- [ ] CloudKit schema: `Group` record type (name, code, adminID, memberIDs, createdAt)
- [ ] **Create Group:** Name input → auto-generate join code → save to CloudKit
- [ ] **My Groups list:** Shows groups where user is admin or member, with role badge
- [ ] **Search/Browse:** Public group listing with real-time text filtering
- [ ] **Join with Code:** Enter alphanumeric code → find group → send join request
- [ ] **Join Request flow:** Request stored in CloudKit, admin sees in Group Detail
- [ ] **Admin actions:** Accept/decline join requests, remove members, delete group
- [ ] **Member actions:** Leave group
- [ ] Group Detail view: member list, pending requests (admin only)

### Acceptance Tests

| # | Test | Pass Criteria |
|---|------|--------------|
| 2.1 | Create group | User creates group "Fitness Crew" → appears in My Groups as Admin |
| 2.2 | Group code generated | Created group has a unique alphanumeric code |
| 2.3 | Search groups | Typing "Fit" filters list to show "Fitness Crew" |
| 2.4 | Join with code | Entering valid code sends join request to group |
| 2.5 | Admin sees pending request | Admin opens group detail → pending request visible |
| 2.6 | Accept request | Admin accepts → member appears in member list |
| 2.7 | Decline request | Admin declines → request removed, requester notified |
| 2.8 | Leave group | Member taps leave → removed from member list |
| 2.9 | Delete group | Admin deletes → group removed from all members' lists |
| 2.10 | 20 member cap | Joining attempt when group is full → shows error message |

### Unit Tests

- Group code generation produces valid alphanumeric string
- Group code is unique (no collision in 1000 generations)
- Search filtering is case-insensitive
- Admin cannot leave their own group (must delete)
- Non-admin cannot access admin actions

---

## Sprint 3 — Friends

**Goal:** Users can find, add, and manage friends.

### Deliverables

- [ ] CloudKit schema: `FriendRequest` (senderID, receiverID, status, createdAt)
- [ ] CloudKit schema: `Friendship` (userIDs pair, createdAt)
- [ ] **Search users:** By username with real-time filtering
- [ ] **Send friend request** from search results
- [ ] **Friend requests management:** Incoming (accept/decline), outgoing (cancel)
- [ ] **Friends list:** All confirmed friends with option to remove
- [ ] **Status badges:** Pending, Friends (matching mockups)

### Acceptance Tests

| # | Test | Pass Criteria |
|---|------|--------------|
| 3.1 | Search by username | Typing partial username shows matching users |
| 3.2 | Send friend request | Tapping "Add" sends request, badge changes to "Pending" |
| 3.3 | Receive friend request | Recipient sees request in Friends tab |
| 3.4 | Accept friend request | Both users now show in each other's friends list |
| 3.5 | Decline friend request | Request removed, no friendship created |
| 3.6 | Remove friend | Removing deletes friendship bidirectionally |
| 3.7 | Cannot self-friend | Own username does not appear in search results |
| 3.8 | No duplicate requests | Sending request to someone with pending request → shows existing status |

### Unit Tests

- Friendship is bidirectional (A→B implies B→A)
- Friend request status transitions are valid (pending → accepted/declined only)
- Search excludes current user and existing friends from "Add" action

---

## Sprint 4 — Inbox

**Goal:** Central notification inbox for all app events.

### Deliverables

- [ ] CloudKit schema: `InboxMessage` (recipientID, type, payload, read, createdAt)
- [ ] Inbox view: Chronological list matching mockup design
- [ ] Message types with appropriate icons and actions:
  - [ ] Group join request (Accept / Decline buttons)
  - [ ] Group request accepted (informational)
  - [ ] Group request declined (informational)
  - [ ] Group deleted (informational)
  - [ ] Friend request (Accept / Decline buttons)
  - [ ] Friend request accepted (informational)
  - [ ] Temporary room invitation (Join / Decline buttons)
- [ ] Unread badge on Inbox tab
- [ ] Mark as read on view
- [ ] Inbox actions trigger the corresponding backend operations (accept/decline flow)

### Acceptance Tests

| # | Test | Pass Criteria |
|---|------|--------------|
| 4.1 | Message appears on event | When User B requests to join User A's group, User A sees inbox message |
| 4.2 | Accept from inbox | Tapping Accept on join request adds member to group |
| 4.3 | Decline from inbox | Tapping Decline removes the request |
| 4.4 | Unread badge | New unread messages show badge count on Inbox tab |
| 4.5 | Mark as read | Opening inbox marks visible messages as read |
| 4.6 | Delete notification | Admin deletes group → all members receive "Group Deleted" message |
| 4.7 | Message ordering | Messages appear newest-first |

### Unit Tests

- Message factory creates correct type for each event
- Read/unread state toggles correctly
- Badge count matches unread message count
- Actions in inbox produce same result as direct actions (accept from inbox = accept from group detail)

---

## Sprint 5 — Heart Rate Pipeline

**Goal:** Stream HR from Apple Watch to iPhone to Firebase, and receive other users' HR from Firebase.

### Deliverables

- [ ] **Watch side:**
  - [ ] HealthKit workout session for continuous HR monitoring
  - [ ] HR sample handler (~1 Hz)
  - [ ] WatchConnectivity: send HR to iPhone via `sendMessage`
- [ ] **iPhone side:**
  - [ ] WatchConnectivity: receive HR from Watch
  - [ ] Firebase Realtime DB: write own HR to room path (`/rooms/{roomID}/users/{userID}`)
  - [ ] Firebase Realtime DB: subscribe to all users in current room
  - [ ] HR data model: `{currentHR, previousHR, timestamp}`
  - [ ] Clean up Firebase on room exit (remove own entry, detach listeners)
- [ ] **HealthKit permissions:** Request HR read access on first room entry
- [ ] **Disconnection handling:** Watch disconnect → auto-leave room

### Firebase Data Structure

```
/rooms/{roomID}/
  users/
    {userID}/
      currentHR: 78
      previousHR: 75
      timestamp: 1707654321
      username: "cosmic_narwhal0042"
```

### Acceptance Tests

| # | Test | Pass Criteria |
|---|------|--------------|
| 5.1 | HealthKit permission | App requests HR permission, user can grant |
| 5.2 | Watch streams HR | Wearing Watch, HR values appear on iPhone console at ~1 Hz |
| 5.3 | Firebase write | Own HR appears in Firebase RTDB at correct room path |
| 5.4 | Firebase read | Other user's HR changes are received within 2 seconds |
| 5.5 | Room exit cleanup | Leaving room removes own data from Firebase |
| 5.6 | Watch disconnect | Disconnecting Watch auto-exits room within 5 seconds |
| 5.7 | Simultaneous users | Two devices in same room both see each other's HR updates |

### Unit Tests

- HR data model serializes/deserializes correctly
- Previous HR is correctly shifted on new sample
- Firebase path construction is correct for given room/user IDs
- Cleanup removes all listeners and data on exit

---

## Sprint 6 — Room Animation

**Goal:** Render the 2D heart rate visualization with smooth movement.

### Deliverables

- [ ] **Canvas/view:** 2D coordinate system with fixed axes (40–200 BPM)
- [ ] **Axis rendering:** Subtle grid lines, axis labels at intervals
- [ ] **Diagonal line:** X = Y reference line (stable HR)
- [ ] **Heart rendering:**
  - [ ] Glassmorphic heart shape (matching design mockups)
  - [ ] User-specific color (random from curated palette on room entry)
  - [ ] Username label below heart (iPhone only)
  - [ ] Own heart visually distinct (slightly larger, glow effect)
- [ ] **Bézier movement:** On each HR update, heart animates from old position to new position using cubic Bézier interpolation
- [ ] **Room view integration:** Embed in Rooms tab, entered from group or temporary room
- [ ] **Simulated data mode:** For development/testing, generate fake HR data for N virtual users

### Acceptance Tests

| # | Test | Pass Criteria |
|---|------|--------------|
| 6.1 | Axes render correctly | 40–200 BPM range visible on both axes, labels readable |
| 6.2 | Own heart visible | User's heart appears at correct position matching their HR |
| 6.3 | Other hearts visible | Simulated users' hearts appear at their respective positions |
| 6.4 | Smooth movement | Heart transitions are visually smooth (no teleporting), curve is visible |
| 6.5 | Color assignment | Each heart has a distinct color |
| 6.6 | Username labels | Usernames visible below hearts on iPhone |
| 6.7 | 60 fps on iPhone | Animation maintains 60 fps with 20 hearts in simulator (Instruments check) |
| 6.8 | Diagonal reference | X = Y line is visible |

### Unit Tests

- Position calculation: HR (75, 80) maps to correct pixel coordinates given view size
- Bézier control point generation produces valid curves
- Color palette has at least 20 distinct colors
- Out-of-range HR (e.g., 250) is clamped to axis bounds

---

## Sprint 7 — Sync Detection & Clusters

**Goal:** Detect synchronized hearts and compute soft/hard clusters in real time.

### Deliverables

- [ ] **Sync detection engine:**
  - [ ] Pairwise distance calculation for all users in room
  - [ ] Threshold: Euclidean distance < 5 BPM in 2D space
  - [ ] Build adjacency graph from pairwise sync status
- [ ] **Cluster computation:**
  - [ ] Connected components → soft clusters (BFS/DFS)
  - [ ] Clique detection → hard clusters (Bron-Kerbosch or brute force for N ≤ 20)
  - [ ] Max chain length (graph diameter via BFS from each node)
- [ ] **Cluster data model:** Published to animation engine and Watch
- [ ] **Performance:** < 50ms computation for 20 users

### Acceptance Tests

| # | Test | Pass Criteria |
|---|------|--------------|
| 7.1 | Pair sync detected | Two users at HR 75 and 78 are marked as synced |
| 7.2 | Pair NOT synced | Two users at HR 75 and 85 are NOT marked as synced |
| 7.3 | Soft cluster: A↔B↔C, not A↔C | A=75, B=79, C=83 → soft cluster of 3, chain length 2 |
| 7.4 | Hard cluster: all connected | A=76, B=78, C=80 → hard cluster of 3 |
| 7.5 | Mixed clusters | Room with both soft and hard clusters renders both correctly |
| 7.6 | Solo user | User not synced with anyone → no cluster |
| 7.7 | Performance benchmark | 20 users, all pairwise computations complete in < 50ms |

### Unit Tests

- `SyncGraph.isEdge(userA, userB)` with known distances
- `SyncGraph.connectedComponents()` returns correct groups
- `SyncGraph.maxCliques()` returns correct cliques
- `SyncGraph.chainLength(component:)` returns correct diameter
- Edge cases: 1 user, 2 users, all 20 synced, none synced
- Deterministic test cases with fixed HR values

---

## Sprint 8 — Sync Effects

**Goal:** Visual and haptic feedback for synchronization events.

### Deliverables

- [ ] **Shared circle:** When two+ hearts are synced, draw a colored circle/ellipse encompassing them
  - [ ] Soft cluster → dashed circle + chain length label
  - [ ] Hard cluster → solid circle + chain length label
- [ ] **Star effect:**
  - [ ] Star spawns at random position when a new sync pair forms
  - [ ] Star drifts randomly (smooth random walk) across the room background
  - [ ] Star fades out after 3 minutes
  - [ ] Multiple stars coexist
  - [ ] Star design matches "rainbow unicorn" aesthetic (sparkle, glow)
- [ ] **Haptic feedback:**
  - [ ] iPhone: `UIImpactFeedbackGenerator(.medium)` on new sync
  - [ ] Apple Watch: `WKInterfaceDevice.current().play(.notification)` on new sync
  - [ ] Haptic fires only on sync **formation** (not continuously while synced)
- [ ] **Cluster info overlay:** Show user's own BPM, max chain, synced count (matching Watch mockup)

### Acceptance Tests

| # | Test | Pass Criteria |
|---|------|--------------|
| 8.1 | Circle appears on sync | Two hearts < 5 BPM apart → colored circle visible around both |
| 8.2 | Circle disappears on desync | Hearts move apart → circle fades out |
| 8.3 | Soft vs hard visual | Soft cluster shows dashed circle, hard shows solid |
| 8.4 | Star spawns | New sync event → star appears in background |
| 8.5 | Star drifts | Star moves across screen over time |
| 8.6 | Star dies after 3 min | Star fades out and is removed after 180 seconds |
| 8.7 | Multiple stars | Two sync events → two stars visible simultaneously |
| 8.8 | Haptic on iPhone | New sync → haptic feedback felt |
| 8.9 | Haptic on Watch | New sync → haptic feedback felt on wrist |
| 8.10 | No continuous haptic | Staying synced does not repeatedly trigger haptics |
| 8.11 | Cluster info overlay | BPM, max chain, synced count visible in corner |

### Unit Tests

- Star lifecycle: spawn → drift → fade → removal
- Star timer fires at 180 seconds
- Haptic trigger fires once per sync formation, not per frame
- Circle geometry correctly encompasses all hearts in a cluster

---

## Sprint 9 — Apple Watch App

**Goal:** Full Watch app with simplified room animation.

### Deliverables

- [ ] **Watch app entry:** Shows current room status (in room / not in room)
- [ ] **Simplified 2D animation:**
  - [ ] Same coordinate system (40–200 BPM) on smaller canvas
  - [ ] Hearts without labels
  - [ ] Own heart visually distinct
  - [ ] Bézier movement (possibly at reduced frame rate)
- [ ] **Stats overlay:** BPM, Max Chain, Synced count (matching mockup)
- [ ] **Haptic feedback** on sync events
- [ ] **HR streaming** from HealthKit workout session (already built in Sprint 5, integrated here)
- [ ] **Sync state** received from iPhone via WatchConnectivity

### Acceptance Tests

| # | Test | Pass Criteria |
|---|------|--------------|
| 9.1 | Watch app launches | Watch shows room status |
| 9.2 | Room animation displays | When in room, 2D plot renders with hearts |
| 9.3 | Own heart moves | HR changes → heart moves smoothly on watch screen |
| 9.4 | Other hearts visible | Other room participants appear as hearts |
| 9.5 | Stats display | BPM, max chain, synced count shown correctly |
| 9.6 | Haptic on sync | Wrist haptic when sync forms |
| 9.7 | 30 fps minimum | Animation does not stutter on Apple Watch |
| 9.8 | No labels on hearts | Hearts render without username text |

### Unit Tests

- Watch receives room state from iPhone correctly
- Stats computed correctly from room state
- Watch HR samples are sent to iPhone at ~1 Hz

---

## Sprint 10 — Temporary Rooms

**Goal:** Two friends can create an ad-hoc room.

### Deliverables

- [ ] **Create temp room:** From Friends list, tap a friend → "Start Room" action
- [ ] **Room invitation:** Send via inbox message (Join / Decline)
- [ ] **Room lifecycle:**
  - [ ] Created when first user enters
  - [ ] Persists as long as at least one user is present
  - [ ] Destroyed when both have left
  - [ ] Friend can re-enter while the other is still present
- [ ] **Room appears in Rooms tab** (marked as "Temporary" or "1-on-1")
- [ ] Firebase room path: `/rooms/temp_{userA}_{userB}/`

### Acceptance Tests

| # | Test | Pass Criteria |
|---|------|--------------|
| 10.1 | Create temp room | Tapping "Start Room" on a friend creates the room |
| 10.2 | Friend receives invite | Friend sees room invitation in inbox |
| 10.3 | Both in room | Both users see each other's hearts in the room |
| 10.4 | One leaves, room persists | User A leaves → User B still in room, room still exists |
| 10.5 | A returns | User A re-enters → both hearts visible again |
| 10.6 | Both leave, room destroyed | Both leave → room no longer in Rooms tab, Firebase cleaned |
| 10.7 | Temp room in Rooms tab | Active temp rooms appear in Rooms list |

### Unit Tests

- Room lifecycle state machine: empty → oneUser → twoUsers → oneUser → empty → destroyed
- Firebase cleanup occurs on room destruction
- Room is correctly marked as temporary vs. group room

---

## Sprint 11 — Settings & Account

**Goal:** User can sign out and delete all their data.

### Deliverables

- [ ] **Settings view** (accessible from profile icon or gear)
- [ ] **Sign out:**
  - [ ] Clear local auth state
  - [ ] Return to Sign in with Apple screen
  - [ ] Leave all active rooms on sign out
- [ ] **Delete my data:**
  - [ ] Confirmation dialog with warning
  - [ ] Delete CloudKit records: UserProfile, group memberships, friend relationships, inbox messages
  - [ ] Delete Firebase data: all room entries
  - [ ] Remove user from all groups they're in
  - [ ] Delete groups they admin (notify members via inbox)
  - [ ] Clear local storage
  - [ ] Sign out after deletion

### Acceptance Tests

| # | Test | Pass Criteria |
|---|------|--------------|
| 11.1 | Sign out | User taps sign out → returns to sign-in screen |
| 11.2 | Session cleared | After sign out, relaunching app shows sign-in screen |
| 11.3 | Delete data confirmation | Tapping delete shows confirmation dialog |
| 11.4 | Delete data executes | After confirmation: CloudKit records removed, Firebase cleaned |
| 11.5 | Group notification | Deleting account while admin → members receive "Group Deleted" |
| 11.6 | Re-sign-in is fresh | Signing in again after deletion → fresh username generation, no old data |

### Unit Tests

- Data deletion removes all record types
- Sign out clears all local state
- Active rooms are exited before sign out completes

---

## Sprint 12 — Dashboard Stubs

**Goal:** Create dashboard section with placeholder UI and define data models for future metrics.

### Deliverables

- [ ] **Dashboard section** in the app (accessible from Settings or as a sub-tab)
- [ ] **"Coming Soon" placeholder** with animated heart + teaser text
- [ ] **Data models defined** (not populated):
  - [ ] `SessionLog` (roomID, userID, joinedAt, leftAt, duration)
  - [ ] `SyncEvent` (roomID, userIDs, startedAt, endedAt, duration)
  - [ ] `DashboardMetrics` (computed model for future use)
- [ ] **Data model documentation** in code comments explaining future use

### Acceptance Tests

| # | Test | Pass Criteria |
|---|------|--------------|
| 12.1 | Dashboard accessible | User can navigate to dashboard section |
| 12.2 | Placeholder displays | "Coming Soon" message with attractive design |
| 12.3 | Models compile | All data models build without errors |
| 12.4 | Models are documented | Each model property has a doc comment |

---

## Sprint 13 — Polish & QA

**Goal:** Refine design, fix bugs, optimize performance, ensure accessibility.

### Deliverables

- [ ] **Design polish:**
  - [ ] Liquid Glass consistency across all views
  - [ ] Rainbow unicorn aesthetic verified against mockups
  - [ ] Animation smoothness and timing review
  - [ ] Loading states and empty states for all views
  - [ ] Error states with friendly messages
- [ ] **Performance:**
  - [ ] Profile with Instruments (Time Profiler, Core Animation)
  - [ ] Memory leak check (Leaks instrument)
  - [ ] Battery impact assessment
- [ ] **Accessibility:**
  - [ ] VoiceOver pass on all screens
  - [ ] Dynamic Type at all sizes
  - [ ] Sufficient contrast ratios
- [ ] **Edge cases:**
  - [ ] Network loss mid-room
  - [ ] App backgrounding while in room
  - [ ] Rapid room join/leave
  - [ ] Max 20 users stress test
- [ ] **Code quality:**
  - [ ] Remove all TODOs and debug code
  - [ ] Consistent code style
  - [ ] Documentation on public interfaces

### Acceptance Tests

| # | Test | Pass Criteria |
|---|------|--------------|
| 13.1 | Visual consistency | All screens match design language (peer review) |
| 13.2 | 60 fps room (iPhone) | Instruments confirms 60 fps with 20 hearts |
| 13.3 | 30 fps room (Watch) | No visible stutter with 20 hearts on Watch |
| 13.4 | No memory leaks | Leaks instrument reports 0 leaks after full session |
| 13.5 | VoiceOver navigable | All screens navigable with VoiceOver |
| 13.6 | Network recovery | Losing and regaining WiFi → app recovers gracefully |
| 13.7 | Background/foreground | App resumes correctly after backgrounding |
| 13.8 | No crashes | Full feature walkthrough with 0 crashes |

---

## Dependencies Between Sprints

```
Sprint 0 (Foundation)
   ├── Sprint 1 (Auth) ← required for all subsequent sprints
   │    ├── Sprint 2 (Groups)
   │    │    └── Sprint 4 (Inbox) ← needs group events
   │    ├── Sprint 3 (Friends)
   │    │    ├── Sprint 4 (Inbox) ← needs friend events
   │    │    └── Sprint 10 (Temp Rooms)
   │    └── Sprint 11 (Settings)
   │
   ├── Sprint 5 (HR Pipeline) ← can parallel with 2-4
   │    ├── Sprint 6 (Room Animation)
   │    │    ├── Sprint 7 (Sync & Clusters)
   │    │    │    └── Sprint 8 (Sync Effects)
   │    │    └── Sprint 9 (Watch App)
   │    └── Sprint 10 (Temp Rooms)
   │
   └── Sprint 12 (Dashboard Stubs) ← can be done anytime after 0
        └── Sprint 13 (Polish) ← after everything else
```

**Parallelization opportunities:**
- Sprints 2/3/4 (social features) can be developed in parallel with Sprint 5 (HR pipeline)
- Sprint 12 (dashboard stubs) can be done at any time
- Sprint 9 (Watch) depends on Sprint 6 (animation) being stable

---

## Git Workflow Reminders

1. **Branch from `main`** for each sprint: `git checkout -b sprint/XX-name`
2. **Commit often** with descriptive messages: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`
3. **Never merge without explicit approval** from Rémy
4. **Never force push, delete branches, or rebase** without explicit approval
5. **Tag each merge** with sprint number: `v0.X.0`
