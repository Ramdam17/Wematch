import Foundation
import OSLog
import WematchCore

@Observable
@MainActor
final class RoomViewModel {

    // MARK: - Published State

    private(set) var participants: [RoomParticipant] = []
    private(set) var ownHeartRate: Double = 0
    private(set) var previousHeartRate: Double = 0
    private(set) var isInRoom = false
    private(set) var isLoading = false
    var error: Error?

    /// What the Watch reports about its own heart-rate feed: a denied read produces
    /// no error and no data, so `.silent`/`.stopped` are the only evidence there is.
    /// Not `private(set)` — the consumer is an extension in another file.
    var watchHeartRateStatus: WatchHeartRateStatus = .idle

    // MARK: - Room Info

    let roomID: String
    let roomName: String

    // MARK: - Dependencies

    private let roomRepository: any RoomRepository
    private let tempRoomRepository: any TemporaryRoomRepository
    /// Internal, not private: the Watch message extension in another file feeds it the
    /// samples the Watch sends.
    let healthKitService: any HealthKitServiceProtocol
    let watchService: any WatchConnectivityServiceProtocol
    private let authManager: AuthenticationManager
    /// Internal, not private: the dashboard recording lives in
    /// `RoomViewModel+DashboardRecording.swift` and an extension in another file cannot
    /// see private members.
    let dashboardStore: any DashboardRecordStoring

    // MARK: - Simulated Participants (plot testing)

    private(set) var simulatedParticipants: [RoomParticipant] = []

    // MARK: - Tasks

    private var observeTask: Task<Void, Never>?
    private var connectionTask: Task<Void, Never>?
    private var heartRateTask: Task<Void, Never>?
    private var simulationTask: Task<Void, Never>?
    /// Internal for the same reason as `watchHeartRateStatus`.
    var watchMessageTask: Task<Void, Never>?

    // MARK: - Simulated Room Service

    #if targetEnvironment(simulator)
    private let simulatedRoomService = SimulatedRoomDataService()
    #endif

    // MARK: - Sync Effects State

    /// Stars spawned by sync formations.
    private(set) var activeStars: [SyncStar] = []

    /// Previous frame's synced pairs for formation detection.
    private var previousSyncedPairs: Set<SyncPair> = []

    /// Timer task for star drift updates.
    private var starTimerTask: Task<Void, Never>?

    // MARK: - Dashboard Recording

    /// Accumulates this session's records; flushed to the store on the way out.
    /// Internal for the same reason as `dashboardStore`.
    var recorder: SyncSessionRecorder?

    // MARK: - Connection Health
    //
    // Three links can break independently; they are folded into one `connectionState`
    // (plan 1.7). Kept separate here because they are *set* in three unrelated places,
    // and merged at the point of reading so precedence lives in one testable function.

    /// The device is not reaching the database at all (`.info/connected`).
    private(set) var isOffline = false

    /// The participants stream threw — permission denied, or a listener the server
    /// refused. Not the same event as `isOffline`, and neither implies the other.
    private(set) var isRoomUnreachable = false

    /// A Watch command could not be delivered at all. Internal rather than
    /// `private(set)` for the same reason as `watchHeartRateStatus`: it is written by
    /// the Watch extension in another file.
    var isWatchUnreachable = false

    /// False while heart-rate writes are failing, true again on the first one that lands.
    private(set) var isSharingHeartRate = true

    /// What the room says about itself. Deliberately not an `error`: `error` presents a
    /// modal alert, which is the wrong shape for a failure that repeats every second and
    /// needs no decision from the user.
    var connectionState: RoomConnectionState {
        RoomConnectionState.resolve(isOffline: isOffline,
                                    roomUnreachable: isRoomUnreachable,
                                    watchUnreachable: isWatchUnreachable,
                                    watchHeartRate: watchHeartRateStatus,
                                    isSharingHeartRate: isSharingHeartRate)
    }

    // MARK: - Participant Color

    /// Internal, not private: read by the plot extension in another file.
    var assignedSlot = HeartPaletteSlot(index: 0)

    // MARK: - Init

    init(roomID: String,
         roomName: String,
         roomRepository: (any RoomRepository)? = nil,
         tempRoomRepository: (any TemporaryRoomRepository)? = nil,
         healthKitService: (any HealthKitServiceProtocol)? = nil,
         watchService: (any WatchConnectivityServiceProtocol)? = nil,
         dashboardStore: (any DashboardRecordStoring)? = nil,
         authManager: AuthenticationManager) {
        self.roomID = roomID
        self.roomName = roomName
        self.roomRepository = roomRepository ?? FirebaseRoomRepository()
        self.tempRoomRepository = tempRoomRepository ?? FirebaseTemporaryRoomRepository()
        // The last `.shared` a ViewModel names, and a default argument rather than a
        // reached-for dependency: every test injects its own, so nothing here ever
        // touches the singleton. It becomes an injected parameter when plan 3c builds
        // the composition root that has somewhere to inject it from.
        self.watchService = watchService ?? PhoneSessionManager.shared
        self.dashboardStore = dashboardStore ?? DashboardRecordStore()
        self.authManager = authManager

        #if targetEnvironment(simulator)
        self.healthKitService = healthKitService ?? SimulatedHeartRateService()
        #else
        self.healthKitService = healthKitService ?? WatchRelayHeartRateService()
        #endif

        // Claim a palette slot from the user ID. Stable across launches and devices,
        // unlike the previous hashValue-based pick. Derived from the firebaseSafe form
        // because that is the ID that travels: a decoder falling back to a local
        // derivation then lands on this same slot rather than a neighbouring hue.
        if let userID = authManager.currentUserID {
            self.assignedSlot = HeartPaletteSlot(userID: userID.firebaseSafe())
        }
    }

    // MARK: - Computed

    var currentUserID: String? { authManager.currentUserID }
    var currentUsername: String { authManager.userProfile?.username ?? "unknown" }

    // MARK: - Room Lifecycle

    func enterRoom() async {
        guard let userID = currentUserID else {
            error = RoomError.notAuthenticated
            return
        }

        isLoading = true
        defer { isLoading = false }

        // The phone asks HealthKit for nothing: heart rate arrives over
        // WatchConnectivity, and the Watch owns its own authorization. It used to
        // request a read it never performed, and present `healthKitDenied` for a
        // refusal HealthKit never reports.

        // 1. Join room in Firebase
        let participant = RoomParticipant(
            id: userID,
            username: currentUsername,
            slot: assignedSlot
        )

        do {
            try await roomRepository.joinRoom(roomID: roomID, participant: participant)
            isInRoom = true

            startDashboardRecording(userID: userID)
        } catch {
            self.error = error
            Log.rooms.error("Failed to join room: \(error.localizedDescription)")
            return
        }

        // 2. Start observing other participants, and the link they arrive over
        startObservingParticipants()
        startObservingConnection()

        startObservingWatchMessages()

        // 3. Start streaming heart rate
        startHeartRateStreaming()

        // 4. On real device: tell the Watch to start its workout. The heart rate it
        // sends back enters through `startObservingWatchMessages` above — no handler
        // installed on a singleton, no downcast of the injected protocol (plan 1.10).
        #if !targetEnvironment(simulator)
        sendWatchCommand(.enterRoom(roomID: roomID))
        #endif

        // 5. Start simulated room participants (simulator only)
        #if targetEnvironment(simulator)
        startSimulatedParticipants()
        #endif

        // 6. Start star drift timer
        startStarTimer()

        // 7. Give the Watch something to show if the user swipes to the dashboard.
        Task { await pushDashboardSnapshotToWatch() }

        Log.rooms.info("Entered room \(self.roomID)")
    }

    func exitRoom() async {
        // Local teardown must run even with NO session left (sign-out or
        // account deletion while in a room — audit C1): never gate task
        // cancellation on having a userID.
        guard isInRoom else { return }

        // 1. Cancel all background tasks
        observeTask?.cancel()
        connectionTask?.cancel()
        heartRateTask?.cancel()
        simulationTask?.cancel()
        starTimerTask?.cancel()
        watchMessageTask?.cancel()
        observeTask = nil
        connectionTask = nil
        heartRateTask = nil
        simulationTask = nil
        starTimerTask = nil
        watchMessageTask = nil
        watchHeartRateStatus = .idle
        // A room we are no longer in has no connection to complain about.
        isOffline = false
        isRoomUnreachable = false
        isWatchUnreachable = false
        isSharingHeartRate = true

        #if targetEnvironment(simulator)
        simulatedRoomService.stopSimulation()
        simulatedParticipants = []
        #endif

        // 2. Stop HR streaming
        healthKitService.stopHeartRateStreaming()

        // 3. Tell the Watch to stop its workout. Nothing to disconnect: the message
        // stream ends with `watchMessageTask`, cancelled in step 1.
        #if !targetEnvironment(simulator)
        sendWatchCommand(.exitRoom)
        #endif

        // 4. Network cleanup — needs an identity; when the session is already
        // gone (sign-out mid-room) we skip it LOUDLY and let the Firebase
        // onDisconnect hook reap the participant node.
        if let userID = currentUserID {
            do {
                try await roomRepository.leaveRoom(roomID: roomID, userID: userID)
            } catch {
                Log.rooms.error("Failed to leave room cleanly: \(error.localizedDescription)")
            }

            // 4b. Temp room cleanup — destroy room + indexes if no participants
            // remain. Member IDs are resolved from room metadata by the
            // repository, never parsed out of the roomID (audit E1).
            if roomID.hasPrefix("temp_") {
                do {
                    let hasOthers = try await tempRoomRepository.hasParticipants(roomID: roomID)
                    if !hasOthers {
                        try await tempRoomRepository.deleteRoom(roomID: roomID)
                        Log.rooms.info("Destroyed temp room \(self.roomID) — no participants left")
                    }
                } catch {
                    Log.rooms.warning("Temp room cleanup failed: \(error.localizedDescription)")
                }
            }
        } else {
            Log.rooms.warning("Exited room with no session — Firebase cleanup skipped, onDisconnect will reap")
        }

        // 5. Close out the dashboard recording for this session.
        await flushDashboardRecords()

        // 6. Clear state
        isInRoom = false
        participants = []
        ownHeartRate = 0
        previousHeartRate = 0
        activeStars = []
        previousSyncedPairs = []

        Log.rooms.info("Exited room \(self.roomID)")
    }

    // MARK: - Sync Effects

    /// Detect new sync formations and trigger effects.
    private func processSyncChanges() {
        let currentPairs = syncGraph.syncedPairs
        let newFormations = currentPairs.subtracting(previousSyncedPairs)

        let hasNewFormations = !newFormations.isEmpty && !previousSyncedPairs.isEmpty

        let starsBeforeSpawn = activeStars.count

        if hasNewFormations {
            // Spawn one star per new sync pair, hard-capped: each star is a
            // blurred repeatForever animation, unbounded spawning is a GPU
            // and battery sink at 20 participants (audit F4).
            let maxActiveStars = 24
            for _ in newFormations where activeStars.count < maxActiveStars {
                let star = SyncStar(
                    position: CGPoint(
                        x: CGFloat.random(in: 0.1...0.9),
                        y: CGFloat.random(in: 0.1...0.9)
                    ),
                    driftVelocity: CGPoint(
                        x: CGFloat.random(in: -0.02...0.02),
                        y: CGFloat.random(in: -0.02...0.02)
                    )
                )
                activeStars.append(star)
            }

            // Haptic feedback
            HapticService.triggerSyncFormation()

            Log.rooms.debug("New sync formations: \(newFormations.count), active stars: \(self.activeStars.count)")
        }

        previousSyncedPairs = currentPairs

        recordDashboardState(starsSpawned: activeStars.count - starsBeforeSpawn)

        // Send room state to Watch
        sendRoomUpdateToWatch(newSyncFormations: hasNewFormations)
    }

    /// Update star positions and remove expired ones.
    private func updateStars() {
        let now = Date()
        let lifetime: TimeInterval = 180 // 3 minutes
        let fadeStart: TimeInterval = 150 // Start fading at 2.5 min

        activeStars.removeAll { now.timeIntervalSince($0.birthDate) > lifetime }

        for i in activeStars.indices {
            // Drift
            activeStars[i].position.x += activeStars[i].driftVelocity.x
            activeStars[i].position.y += activeStars[i].driftVelocity.y

            // Wrap around edges
            if activeStars[i].position.x < 0 { activeStars[i].position.x = 1 }
            if activeStars[i].position.x > 1 { activeStars[i].position.x = 0 }
            if activeStars[i].position.y < 0 { activeStars[i].position.y = 1 }
            if activeStars[i].position.y > 1 { activeStars[i].position.y = 0 }

            // Fade
            let age = now.timeIntervalSince(activeStars[i].birthDate)
            if age > fadeStart {
                activeStars[i].opacity = 1.0 - (age - fadeStart) / (lifetime - fadeStart)
            }
        }
    }

    private func startStarTimer() {
        starTimerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { break }
                updateStars()
            }
        }
    }

    // MARK: - Private: Observation

    private func startObservingConnection() {
        connectionTask = Task {
            for await isConnected in roomRepository.observeConnection() {
                guard !Task.isCancelled else { break }
                self.isOffline = !isConnected
            }
        }
    }

    private func startObservingParticipants() {
        observeTask = Task {
            do {
                for try await updatedParticipants in roomRepository.observeParticipants(roomID: roomID) {
                    guard !Task.isCancelled else { break }
                    self.isRoomUnreachable = false
                    self.participants = updatedParticipants
                    processSyncChanges()
                }
            } catch is CancellationError {
                // Leaving the room, not a fault.
            } catch {
                // The plot is now a photograph of the past, and says so (plan 1.7, D2).
                Log.rooms.error("Room stream lost: \(error.localizedDescription)")
                self.isRoomUnreachable = true
            }
        }
    }

    // MARK: - Private: Heart Rate Streaming

    private func startHeartRateStreaming() {
        let stream = healthKitService.startHeartRateStreaming()

        heartRateTask = Task {
            for await hr in stream {
                guard !Task.isCancelled, isInRoom else { break }

                // Shift HR values
                self.previousHeartRate = self.ownHeartRate
                self.ownHeartRate = hr

                // Write to Firebase
                guard let userID = currentUserID else { continue }
                let data = HeartRateData(
                    currentHR: hr,
                    previousHR: self.previousHeartRate
                )

                do {
                    try await roomRepository.updateHeartRate(
                        roomID: roomID,
                        userID: userID,
                        data: data,
                        username: currentUsername,
                        slot: assignedSlot
                    )
                    // A single success means the room is seeing us again.
                    isSharingHeartRate = true
                } catch {
                    // Surfaced, not just logged (audit D). Deliberately not thrown into
                    // `error`: that drives a modal alert, and this fires once a second
                    // while the network is down. One quiet banner, cleared on recovery.
                    Log.rooms.error("Failed to update HR: \(error.localizedDescription)")
                    isSharingHeartRate = false
                }
            }
        }
    }

    // MARK: - Private: Simulated Participants

    #if targetEnvironment(simulator)
    private func startSimulatedParticipants() {
        let stream = simulatedRoomService.startSimulation()
        simulationTask = Task {
            for await simParticipants in stream {
                guard !Task.isCancelled else { break }
                self.simulatedParticipants = simParticipants
                processSyncChanges()
            }
        }
    }
    #endif
}
