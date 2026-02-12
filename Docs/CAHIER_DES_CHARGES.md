# Wematch — Specification Document

> **Version:** 1.0
> **Date:** February 11, 2026
> **Status:** Draft — Awaiting Validation

---

## 1. Vision & Purpose

Wematch is an iPhone + Apple Watch application that creates a shared, real-time heart rate synchronization experience between users. When two or more users' heart rates come within 5 BPM of each other, they become visually and haptically "connected." The app combines social features (groups, friends, messaging) with a mesmerizing animated visualization of cardiac proximity.

The aesthetic is **"rainbow unicorn"** — joyful, colorful, and luminous — built on Apple's **Liquid Glass** design language (iOS 26+).

---

## 2. Target Platforms

| Platform | Minimum Version | Role | Xcode Target |
|----------|----------------|------|-------------|
| iPhone | iOS 26+ | Primary device — full experience | `Wematch` (exists) |
| Apple Watch | watchOS 26+ | HR sensor + simplified room animation | `WematchWatch` (to be created in Sprint 0) |

No iPad, Mac, or other device support is planned for v1.

> **Note:** The project uses "Wematch" (lowercase 'm') everywhere — code, documentation, and UI. A shared framework target `WematchShared` will also be created in Sprint 0 for code shared between iPhone and Watch.

---

## 3. Technical Architecture

### 3.1 Backend — Hybrid Model

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Real-time HR sync** | Firebase Realtime Database | Streaming heart rate data at ~1 Hz between room participants. Minimal data volume (1 number per user per second). Free tier supports ~100 simultaneous connections. |
| **Persistent data** | CloudKit (public & private databases) | User profiles, groups, friend relationships, inbox messages, room metadata. Free, native to Apple ecosystem, handles authentication via Apple ID. |

**Rationale:** Firebase RTDB provides true real-time subscriptions with sub-second latency, which CloudKit subscriptions cannot guarantee. CloudKit handles everything else for free with tight Apple ecosystem integration.

### 3.2 Data Flow — Heart Rate Pipeline

```
Apple Watch (HealthKit workout session)
    ↓ HKLiveWorkoutBuilder (~1 Hz)
iPhone (WatchConnectivity)
    ↓ WCSession.sendMessage / transferCurrentComplicationUserInfo
Firebase Realtime Database
    ↓ .observe(.value) listeners
Other participants' iPhones
    ↓ Animation engine
Room visualization
```

### 3.3 Authentication

- **Sign in with Apple** (AuthenticationServices framework) — sole authentication method
- Creates a CloudKit user profile on first sign-in
- Username auto-generated (see §5.1), editable once
- **No FaceID** — the existing Face ID capability in the Xcode project must be removed in Sprint 0
- No password, no re-authentication after initial sign-in
- Session persists until explicit logout

### 3.4 Data Privacy

- **Heart rate values are ephemeral** — streamed to Firebase, never persisted beyond the active room session
- **No numeric HR is displayed** for other users — position in the 2D plot is the only indication
- **Own HR** is displayed numerically on the user's own device
- HR data deleted from Firebase when user leaves the room
- Full data deletion available in Settings (CloudKit + Firebase)
- Language: English only

### 3.5 Required Capabilities (Xcode)

**iPhone target (Wematch):**

| Capability | Status | Notes |
|-----------|--------|-------|
| Sign in with Apple | ❌ To add | Required for authentication |
| CloudKit | ❌ To add | Container for persistent data |
| HealthKit | ✅ Present | Background Delivery enabled, HR read |
| Background Modes | ✅ Present | May need "Remote notifications" for CloudKit subscriptions |
| Face ID | ⚠️ To **remove** | Not used in v1 |

**Watch target (WematchWatch — to be created):**

| Capability | Notes |
|-----------|-------|
| HealthKit | Workout session for continuous HR monitoring |

---

## 4. Core Features

### 4.1 The Room (Heart Rate Visualization)

The room is the central experience — a 2D animated space where each participant is represented by a heart icon.

#### 4.1.1 Coordinate System

- **X axis:** Previous heart rate (HR at t-1)
- **Y axis:** Current heart rate (HR at t)
- **Axes bounds:** Fixed, 40–200 BPM
- **Diagonal (X = Y):** Represents stable heart rate
- Above diagonal → HR accelerating; below → HR decelerating

#### 4.1.2 Heart Icons

- Each user gets a **random color** assigned on room entry (from a curated rainbow palette)
- **iPhone:** Heart icon + username label
- **Apple Watch:** Heart icon only (no label, screen too small)
- Movement between positions uses **cubic Bézier curves** for smooth animation
- Update frequency: ~1 second (matching HR sensor cadence)

#### 4.1.3 Synchronization Detection

Two hearts are **synchronized** when their Euclidean distance in HR space is **< 5 BPM**.

More precisely: `sqrt((HR_A_current - HR_B_current)² + (HR_A_previous - HR_B_previous)²) < 5`

> **Design decision:** We use Euclidean distance in the 2D plot space (not just current HR difference) so that visual proximity in the animation matches sync status. Two users at (70,75) and (74,72) are close on screen and also "synced."

#### 4.1.4 Sync Effects

When two hearts become synchronized:

1. **Colored circle** — Both hearts are enclosed in a shared circle of matching color
2. **Haptic feedback** — Triggered on both iPhone and Apple Watch (using `WKInterfaceDevice` / `UIImpactFeedbackGenerator`)
3. **Star spawn** — A decorative star appears in the background
   - The star drifts randomly across the screen for **3 minutes**
   - Then fades out and disappears
   - Multiple stars can coexist (one per new sync event)
   - Stars accumulate → "lighting up the night sky"

#### 4.1.5 Clusters

Clusters are computed from the pairwise sync graph (where an edge means < 5 BPM distance).

| Type | Definition | Visual Indicator |
|------|-----------|-----------------|
| **Soft cluster** | Connected component in the sync graph — A↔B↔C but not necessarily A↔C. Transitive chain. | Dashed/transparent shared boundary + max chain length displayed |
| **Hard cluster** | Complete subgraph (clique) — every pair within the group is synced | Solid shared boundary + max chain length displayed |

- Chain length = the longest path in the connected component (graph diameter)
- A user can see their own cluster info: type (soft/hard), chain length, number of synced peers
- On Apple Watch: simplified cluster indicator (BPM, max chain, synced count — as shown in mockups)

#### 4.1.6 Room Capacity

- **Maximum 20 users per room**

### 4.2 Groups

#### 4.2.1 Group Lifecycle

- Any user can **create** a group (becomes admin)
- Groups are **publicly listed** and searchable (real-time filtering as user types)
- Users can also **join with a code** (alphanumeric, generated at group creation)
- Joining requires admin approval (request → accept/decline flow)
- Admin can **remove members** and **delete the group**
- Members can **leave** a group at any time

#### 4.2.2 Group Properties

| Field | Details |
|-------|---------|
| Name | Set by admin, searchable |
| Code | Auto-generated alphanumeric, shareable |
| Admin | Creator (single admin per group in v1) |
| Members | Up to 20 |
| Room | Each group has a persistent room |

### 4.3 Friends

#### 4.3.1 Friend System

- Search users by **username** (real-time filtering)
- Send friend request → other user accepts or declines
- Remove a friend at any time
- Friends list is bidirectional (if A is friends with B, B is friends with A)

#### 4.3.2 Temporary 1-on-1 Rooms

- Two friends can create a **temporary room** (no group required)
- Room persists as long as **at least one** of the two friends remains in it
- Destroyed when **both** have left
- The friend who left can re-enter as long as the other is still present

### 4.4 Inbox (In-App Notifications)

The inbox aggregates all actionable messages. **No push notifications** — only in-app.

| Event | Message | Action |
|-------|---------|--------|
| Someone requests to join your group | "Alex wants to join your group!" | Accept / Decline |
| Your join request was accepted | "You've been accepted into 'Yoga Circle'" | — |
| Your join request was declined | "Your request to join 'Yoga Circle' was declined" | — |
| A group you're in was deleted | "Harmony Haven has been deleted" | — |
| Friend request received | "StarlightSara wants to be your friend" | Accept / Decline |
| Friend request accepted | "ZachJoyride accepted your friend request" | — |
| Friend request declined | "Your friend request was declined" | — |
| Temporary room invitation | "Alex invited you to a room" | Join / Decline |

### 4.5 Settings

- **Sign out** — Clears local session, returns to Sign in with Apple screen
- **Delete my data** — Removes all CloudKit records, Firebase data, and local data. Irreversible. Requires confirmation dialog.
- **Future:** Dashboard preferences, notification preferences

### 4.6 Dashboards (Placeholder for v2)

The architecture must support future analytics. Planned metrics include:

- Total time spent in rooms
- Total time synced with others
- Longest sync chain achieved
- Longest single sync duration
- Most frequently synced partner
- Number of rooms joined
- Number of stars generated

> In v1, the dashboard section exists as a visible tab/section with a "Coming Soon" placeholder and the data models are defined but not populated.

---

## 5. User Account

### 5.1 Username Generation

On first sign-in, a username is auto-generated using:

```
{adjective}_{animal}{random_number}
```

- **Adjectives:** Curated list of ~100 positive/fun adjectives (e.g., `bubbly`, `cosmic`, `dazzling`, `funky`, `glittery`, `jazzy`, `luminous`, `sparkly`, `whimsical`, `zesty`)
- **Animals:** Curated list of ~100 animals (e.g., `axolotl`, `capybara`, `flamingo`, `hedgehog`, `narwhal`, `octopus`, `pangolin`, `quokka`, `toucan`, `unicorn`)
- **Number:** 0–9999, zero-padded to 4 digits
- Example: `cosmic_narwhal0042`, `sparkly_axolotl7891`
- A **shuffle button** lets the user regenerate until they find one they like
- **Uniqueness** is enforced via CloudKit query before confirming
- Username can be edited once (with uniqueness check)

### 5.2 User Profile (CloudKit)

| Field | Type | Notes |
|-------|------|-------|
| `userID` | String | Apple Sign-In identifier |
| `username` | String | Unique, generated or custom |
| `displayName` | String | Optional, from Apple Sign-In |
| `createdAt` | Date | Account creation timestamp |
| `usernameEdited` | Bool | Track if username was already changed |

---

## 6. Apple Watch App

### 6.1 Capabilities

| Feature | Supported |
|---------|-----------|
| HR streaming to iPhone | ✅ |
| Simplified room animation (2D plot) | ✅ |
| Haptic feedback on sync | ✅ |
| Stats overlay (BPM, max chain, synced count) | ✅ |
| Group management | ❌ |
| Friend management | ❌ |
| Inbox | ❌ |
| Settings | ❌ |
| Dashboards (simplified, future) | 🔮 Planned |

### 6.2 Watch ↔ iPhone Communication

- **WatchConnectivity** framework
- Watch sends HR data to iPhone via `sendMessage` (real-time) with `transferCurrentComplicationUserInfo` as fallback
- iPhone sends room state (other users' positions, sync status) back to Watch
- If Watch loses connectivity → user is auto-removed from the room

---

## 7. Design Language

### 7.1 Aesthetic: Rainbow Unicorn × Liquid Glass

Based on the provided mockups, the design combines:

- **Liquid Glass** translucency and depth (frosted glass cards, blur effects, depth layering)
- **Rainbow gradients** — pink-to-purple-to-blue spectrum as primary palette
- **Sparkle effects** — stars, glitter particles in backgrounds
- **Heart motif** — glass-like 3D hearts with inner glow and refraction
- **Two possible themes (v1 ships one, v2 adds choice):**
  - **Pastel light** (Image 2) — Soft pink/lavender background, gentler tones → **v1 default**
  - **Dark cosmic** (Image 1) — Deep space background with nebula gradients, more vivid neons → **v2**

### 7.2 Key UI Components (from mockups)

- **Tab bar:** Rooms | Groups | Friends | Inbox (with mail icon)
- **Cards:** Frosted glass with subtle border glow
- **Buttons:** Gradient fills (pink-to-cyan for primary actions)
- **Badges:** Colored pills for status (Pending, Friends, Admin, Member)
- **Heart icons:** 3D glass hearts with inner sparkle
- **Background:** Animated gradient with floating particles/stars

### 7.3 Typography

- SF Pro / SF Rounded (system fonts) — consistent with iOS 26
- Bold weights for headings, regular for body
- White or near-white text on dark backgrounds

---

## 8. Navigation Structure (iPhone)

```
TabView
├── Rooms
│   ├── List of active rooms (groups you're in + temporary rooms)
│   └── Room Detail (the 2D animation)
├── Groups
│   ├── My groups list (admin vs member roles)
│   ├── Search / Browse public groups
│   ├── Create Group
│   ├── Join with Code
│   └── Group Detail (members, pending requests)
├── Friends
│   ├── Friends list
│   ├── Search users
│   └── Pending requests (sent / received)
├── Inbox
│   └── Chronological list of notifications with actions
└── Settings (via gear icon or profile)
    ├── Sign out
    ├── Delete my data
    └── Dashboard (Coming Soon placeholder)
```

---

## 9. Non-Functional Requirements

### 9.1 Performance

- Room animation: 60 fps on iPhone, 30 fps minimum on Apple Watch
- HR update latency: < 2 seconds end-to-end (Watch → Firebase → other user's iPhone)
- Room supports 20 simultaneous users without frame drops
- Cluster computation: < 50ms for 20 users (190 possible pairs)

### 9.2 Battery

- Background HR streaming should use HealthKit workout session (optimized by Apple)
- Firebase listeners scoped to active room only (disconnect on room exit)
- No background processing when app is not in use

### 9.3 Accessibility

- VoiceOver support for all navigation and controls
- Dynamic Type support
- Haptic feedback as complement (not sole indicator) for sync events

### 9.4 Error Handling

- Graceful degradation on network loss (show "reconnecting" state)
- Auto-leave room on Watch disconnection
- Retry logic for CloudKit / Firebase operations
- Clear error messages (no technical jargon)

---

## 10. Modularity & Future Evolution

### 10.1 Design Principle

The entire architecture must be designed with **modularity** as a core principle. Even though v1 is free with all features accessible, the codebase must anticipate future changes in business model, feature gating, and platform expansion.

### 10.2 Feature Gating

All major features should be accessible through a **feature flag system** (a simple local configuration layer in v1, replaceable by a remote config service later):

- Room access
- Group creation (number of groups a user can create/join)
- Friend list size
- Temporary room creation
- Dashboard access
- Future: custom heart skins, custom room backgrounds, advanced analytics

The feature flag layer should be a protocol-based abstraction so that the backing store can be swapped from local defaults to Firebase Remote Config or similar without touching feature code.

### 10.3 Architectural Boundaries

Each feature module (Rooms, Groups, Friends, Inbox, Dashboard, Settings) must:

- Expose a clean **public interface** (protocol or `@Observable` ViewModel)
- Own its own **data layer** (repository pattern)
- Be independently testable
- Be removable or replaceable without cascading changes

Services (CloudKit, Firebase, HealthKit, WatchConnectivity) must be accessed through **protocol abstractions**, never directly from Views or ViewModels.

### 10.4 Anticipated Evolutions

| Area | Current (v1) | Future possibility |
|------|-------------|-------------------|
| Monetization | Free, all features | Freemium tiers, in-app purchases |
| Theme | Pastel light only | Dark cosmic, custom themes |
| Notifications | In-app only | Push notifications (APNs) |
| Groups | Single admin | Co-admins, roles |
| Friends | Username search | QR code, contacts import, share link |
| Dashboards | Placeholder | Full analytics with data persistence |
| Platforms | iPhone + Apple Watch | iPad, Mac (Catalyst/native) |
| Localization | English only | French, other languages |
| Peripherals | Apple Watch only | Third-party HR monitors (Bluetooth) |
| Social | Basic groups & friends | Challenges, achievements, leaderboards |

---

## 11. Out of Scope (v1)

- Push notifications (APNs)
- iPad / Mac support
- Multiple admins per group
- Dashboard data collection and display
- Dark cosmic theme (v2)
- QR code / link sharing for friend invites
- Profile pictures / custom avatars
- In-app purchases / monetization
- Localization (English only)
- Android / Wear OS
