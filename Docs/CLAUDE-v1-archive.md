# Wematch — Claude Code Configuration

## Project Overview

Wematch is an iOS 26+ / watchOS 26+ application for real-time heart rate synchronization between users. Users join rooms where their heart rates are visualized as animated hearts on a 2D plot. When hearts synchronize (< 5 BPM apart), visual and haptic effects are triggered.

**Tech stack:** Swift, SwiftUI, HealthKit, WatchConnectivity, CloudKit, Firebase Realtime Database
**Design language:** "Rainbow Unicorn" aesthetic (pastel light theme) on Apple's Liquid Glass (iOS 26+)
**Platforms:** iPhone + Apple Watch only. No iPad, no Mac.

### Current Project State (as of Sprint 0 start)

The Xcode project exists with a single iPhone target. Known state:

| Item | Status |
|------|--------|
| iPhone target | ✅ Exists (Wematch) |
| Apple Watch target | ❌ **Must be created** |
| Shared framework target | ❌ **Must be created** |
| HealthKit capability | ✅ Configured (Background Delivery on, Health Update description present) |
| Face ID capability | ⚠️ **Must be REMOVED** (not used in v1) |
| Sign in with Apple capability | ❌ **Must be added** |
| CloudKit capability | ❌ **Must be added** |
| Background Modes | ✅ Present but nothing checked yet |
| Firebase SDK | ❌ **Must be added** (via SPM) |

**Sprint 0 must address all ❌ and ⚠️ items before feature work begins.**

## Critical Rules

### Git — NEVER without explicit approval

- **NEVER commit** without Rémy's explicit approval
- **NEVER merge branches** without Rémy's explicit approval
- **NEVER force push, rebase, or delete branches** without Rémy's explicit approval
- **NEVER create or delete tags** without Rémy's explicit approval
- You may stage files (`git add`) and show diffs, but the actual commit/push requires approval
- Branch naming: `sprint/XX-short-description`
- Commit message prefixes: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`

### Code Quality

- **All code in English** — variable names, function names, comments, documentation
- **All UI text in English** — no localization for v1
- **SwiftUI only** — no UIKit unless absolutely necessary (e.g., specific haptic APIs)
- **iOS 26+ / watchOS 26+** — use the latest APIs freely, no backward compatibility
- **Prefer `@Observable` over `ObservableObject`** (Swift 5.9+ observation)
- **Prefer Swift Concurrency** (`async/await`, `Task`, actors) over Combine or callbacks
- **No force unwraps** (`!`) except in tests or previews
- **No print statements in production code** — use `os.Logger` for debugging
- **SwiftLint compliance** if configured

### Architecture

Follow **MVVM** with clear separation:

```
Wematch/                          # iPhone app target
├── App/                          # App entry points
│   ├── WematchApp.swift          # iPhone app entry (already exists)
│   └── ContentView.swift         # Root view with TabView (already exists, to be refactored)
├── Core/                         # Shared infrastructure
│   ├── Authentication/           # Sign in with Apple, session management
│   ├── CloudKit/                 # CloudKit managers and record types
│   ├── Firebase/                 # Firebase RTDB manager
│   ├── HealthKit/                # HR streaming
│   ├── WatchConnectivity/        # Watch ↔ iPhone bridge
│   ├── FeatureFlags/             # FeatureFlagProvider protocol + LocalFeatureFlagProvider
│   ├── Services/                 # Service protocol definitions (abstractions layer)
│   └── Design/                   # Design system (colors, fonts, components)
├── Features/                     # Feature modules
│   ├── Rooms/                    # Room list + room animation
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   ├── Models/
│   │   └── Repositories/
│   ├── Groups/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   ├── Models/
│   │   └── Repositories/
│   ├── Friends/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   ├── Models/
│   │   └── Repositories/
│   ├── Inbox/
│   │   ├── Views/
│   │   ├── ViewModels/
│   │   ├── Models/
│   │   └── Repositories/
│   ├── Settings/
│   │   ├── Views/
│   │   └── ViewModels/
│   └── Dashboard/
│       ├── Views/
│       └── Models/
├── Shared/                       # Shared models, extensions, utilities
│   ├── Models/
│   ├── Extensions/
│   └── Utilities/
└── Resources/                    # Assets, dictionaries
    ├── Assets.xcassets            # (already exists)
    ├── Adjectives.json
    └── Animals.json

WematchWatch/                     # Watch app target (TO BE CREATED in Sprint 0)
├── WematchWatchApp.swift         # Watch app entry point
├── Views/
│   ├── RoomView.swift            # Simplified 2D animation
│   └── StatsOverlayView.swift
├── Managers/
│   ├── HapticManager.swift
│   └── WatchSessionManager.swift
└── Resources/
    └── Assets.xcassets

WematchShared/                    # Shared framework (TO BE CREATED in Sprint 0)
├── Models/                       # Shared data models (HR, Room state, Sync state)
├── SyncEngine/                   # Sync detection, cluster algorithms
└── Constants.swift
```

**Important:** The project uses "Wematch" (lowercase 'm') everywhere — code, project references, documentation, and UI. Keep this consistent across all targets and bundle IDs.

### Naming Conventions

| Entity | Convention | Example |
|--------|-----------|---------|
| Types / Protocols | UpperCamelCase | `HeartRateManager`, `SyncDetectable` |
| Functions / Properties | lowerCamelCase | `fetchGroups()`, `currentHeartRate` |
| Constants | lowerCamelCase or UPPER_SNAKE for env | `maxGroupSize`, `FIREBASE_URL` |
| Views | Suffix with `View` | `RoomAnimationView`, `GroupListView` |
| ViewModels | Suffix with `ViewModel` | `GroupListViewModel` |
| CloudKit record types | UpperCamelCase | `UserProfile`, `Group`, `FriendRequest` |
| Firebase paths | snake_case | `/rooms/{room_id}/users/{user_id}` |
| Files | Match the primary type they contain | `HeartRateManager.swift` |

### Testing

- **Unit tests** for all business logic (sync detection, cluster algorithms, username generation, data models)
- **Test file naming:** `{ClassName}Tests.swift`
- **Use XCTest** — test target: `WematchTests`
- **Mocks/stubs** for CloudKit and Firebase in tests
- **Simulated HR data** mode for UI development and testing

### Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Real-time data | Firebase Realtime DB | Sub-second latency, free tier sufficient |
| Persistent data | CloudKit | Free, native Apple, handles auth |
| HR source | HealthKit workout session | Only reliable way to get continuous HR from Apple Watch |
| Watch ↔ iPhone | WatchConnectivity | Native, reliable for paired devices |
| UI framework | SwiftUI | iOS 26+ means full SwiftUI support including Liquid Glass |
| State management | `@Observable` + `@Environment` | Modern Swift observation, no Combine overhead |
| Concurrency | Swift Concurrency | `async/await`, structured concurrency, actors |
| Sync threshold | Euclidean distance < 5 BPM in 2D | Matches visual proximity in the animation |
| Axes | Fixed 40–200 BPM | Consistent visual mapping, no misleading dynamic scaling |
| Max group size | 20 users | Manageable cluster computation and animation performance |

### Design System Reference

**v1 Theme: Pastel Light (Rainbow Unicorn)**
- Background: Soft pink-lavender gradient (#FDF2F8 → #F3E8FF → #EDE9FE)
- Primary gradient: Pink (#FF6B9D) → Purple (#C084FC) → Cyan (#67E8F9)
- Glass effect: White at 40-60% opacity with blur, subtle pink tint
- Heart colors: Curated set of 20+ distinct, vibrant colors (saturated but soft)
- Text: Dark gray (#1F1F1F) on light backgrounds, white on colored surfaces
- Cards: Frosted white glass with soft pink/purple border glow
- Sparkles/particles: Subtle, white/gold on pastel background

> Dark cosmic theme (deep space background, vivid neons, white text) is planned for v2 as a theme toggle.

**Components to build in Sprint 0:**
- `GlassCard` — Frosted glass container with optional glow border
- `GradientButton` — Primary action button with pink-to-cyan gradient
- `StatusBadge` — Colored pill (Pending, Friends, Admin, Member)
- `AnimatedBackground` — Pastel gradient + floating sparkle particles
- `HeartIcon` — Glassmorphic 3D heart with inner glow

### Modularity & Future-Proofing

**Feature Flags:**
- All gatable features go through `FeatureFlag` protocol
- v1 uses `LocalFeatureFlagProvider` (all enabled)
- Future: swap to `RemoteFeatureFlagProvider` (Firebase Remote Config or similar)
- Check flags in ViewModels, never in Views directly

**Service Abstractions:**
- Every external service (CloudKit, Firebase, HealthKit, WatchConnectivity) must be accessed through a **protocol**
- ViewModels depend on protocols, not concrete implementations
- This enables: testing with mocks, swapping backends, and future platform expansion

**Repository Pattern:**
- Each feature domain has a repository protocol (e.g., `GroupRepository`, `FriendRepository`)
- Concrete implementations handle CloudKit/Firebase specifics
- ViewModels only see the repository interface

**Example:**
```swift
// ✅ CORRECT — ViewModel depends on protocol
@Observable
class GroupListViewModel {
    private let repository: any GroupRepository
    private let featureFlags: any FeatureFlagProvider
    
    var canCreateGroup: Bool {
        featureFlags.isEnabled(.groupCreation)
    }
}

// ❌ WRONG — ViewModel depends on concrete CloudKit
@Observable
class GroupListViewModel {
    private let container = CKContainer.default()
}
```

### Firebase Realtime Database Structure

```
/rooms/
  {roomID}/
    metadata/
      type: "group" | "temporary"
      groupID: "{cloudkit_group_id}" (if group)
      createdAt: timestamp
    users/
      {userID}/
        currentHR: number
        previousHR: number
        timestamp: number
        username: string
        color: string (hex)
```

### CloudKit Record Types

```
UserProfile:    userID, username, displayName, createdAt, usernameEdited
Group:          groupID, name, code, adminID, memberIDs, createdAt
JoinRequest:    requestID, groupID, userID, status, createdAt
FriendRequest:  requestID, senderID, receiverID, status, createdAt
Friendship:     friendshipID, userIDs, createdAt
InboxMessage:   messageID, recipientID, type, payload, read, createdAt
```

## Sprint Reference

Current sprint plan is in `SPRINTS.md`. Full specification in `CAHIER_DES_CHARGES.md`.

When starting work on a sprint:
1. Read the sprint section in `SPRINTS.md`
2. Create branch `sprint/XX-name` from `main`
3. Implement deliverables
4. Verify all acceptance tests pass
5. Run unit tests
6. **Wait for Rémy's approval before committing**

## Common Pitfalls to Avoid

- **Don't access services directly from Views or ViewModels** — always go through protocol abstractions and repositories
- **Don't hardcode feature availability** — use the `FeatureFlagProvider` protocol, even if all flags are `true` in v1
- **Don't use `@Published` / `ObservableObject`** — use `@Observable` macro instead
- **Don't use Combine** for new code — use `async/await` and `AsyncSequence`
- **Don't hardcode Firebase URLs** — use configuration
- **Don't store HR data persistently** — ephemeral only
- **Don't show numeric HR for other users** — position only
- **Don't use UIKit views** unless SwiftUI has no equivalent
- **Don't use `print()`** — use `os.Logger`
- **Don't commit without approval**
- **Don't create tight coupling between feature modules** — each module should be independently removable
