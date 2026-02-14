import Foundation
import OSLog

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

    // MARK: - Room Info

    let roomID: String
    let roomName: String

    // MARK: - Dependencies

    private let roomRepository: any RoomRepository
    private let healthKitService: any HealthKitServiceProtocol
    private let watchService: any WatchConnectivityServiceProtocol
    private let authManager: AuthenticationManager

    // MARK: - Simulated Participants (plot testing)

    private(set) var simulatedParticipants: [RoomParticipant] = []

    // MARK: - Tasks

    private var observeTask: Task<Void, Never>?
    private var heartRateTask: Task<Void, Never>?
    private var simulationTask: Task<Void, Never>?

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

    // MARK: - Participant Color

    private var assignedColor: String = "FF6B9D"

    // MARK: - Init

    init(roomID: String,
         roomName: String,
         roomRepository: (any RoomRepository)? = nil,
         healthKitService: (any HealthKitServiceProtocol)? = nil,
         watchService: (any WatchConnectivityServiceProtocol)? = nil,
         authManager: AuthenticationManager) {
        self.roomID = roomID
        self.roomName = roomName
        self.roomRepository = roomRepository ?? FirebaseRoomRepository()
        self.watchService = watchService ?? PhoneSessionManager.shared
        self.authManager = authManager

        #if targetEnvironment(simulator)
        self.healthKitService = healthKitService ?? SimulatedHeartRateService()
        #else
        self.healthKitService = healthKitService ?? HealthKitHeartRateService()
        #endif

        // Assign a color from the palette based on userID hash
        if let userID = authManager.currentUserID {
            let index = abs(userID.hashValue) % WematchTheme.heartColors.count
            self.assignedColor = WematchTheme.heartColorHexes[index]
        }
    }

    // MARK: - Computed

    var currentUserID: String? { authManager.currentUserID }
    var currentUsername: String { authManager.userProfile?.username ?? "unknown" }

    var otherParticipants: [RoomParticipant] {
        participants.filter { $0.id != currentUserID }
    }

    var participantCount: Int { participants.count }

    /// All participants for the 2D plot, including self and simulated users.
    var allParticipantsForPlot: [RoomParticipant] {
        var result = participants

        // Add self if not already in Firebase participants (edge case during join)
        if let userID = currentUserID, !result.contains(where: { $0.id == userID }), ownHeartRate > 0 {
            result.append(RoomParticipant(
                id: userID,
                username: currentUsername,
                currentHR: ownHeartRate,
                previousHR: previousHeartRate,
                color: assignedColor
            ))
        }

        #if targetEnvironment(simulator)
        result.append(contentsOf: simulatedParticipants)
        #endif

        return result
    }

    /// Sync graph computed from current participants.
    var syncGraph: SyncGraph {
        SyncGraph(participants: allParticipantsForPlot)
    }

    // MARK: - Room Lifecycle

    func enterRoom() async {
        guard let userID = currentUserID else {
            error = RoomError.notAuthenticated
            return
        }

        isLoading = true
        defer { isLoading = false }

        // 1. Request HealthKit authorization if needed
        if !healthKitService.isAuthorized {
            do {
                try await healthKitService.requestAuthorization()
            } catch {
                self.error = RoomError.healthKitDenied
                Log.rooms.error("HealthKit authorization denied: \(error.localizedDescription)")
                return
            }
        }

        // 2. Join room in Firebase
        let participant = RoomParticipant(
            id: userID,
            username: currentUsername,
            color: assignedColor
        )

        do {
            try await roomRepository.joinRoom(roomID: roomID, participant: participant)
            isInRoom = true
        } catch {
            self.error = error
            Log.rooms.error("Failed to join room: \(error.localizedDescription)")
            return
        }

        // 3. Start observing other participants
        startObservingParticipants()

        // 4. Start streaming heart rate
        startHeartRateStreaming()

        // 5. On real device: wire Watch HR → HealthKit stream, then tell Watch to start
        #if !targetEnvironment(simulator)
        if let hkService = healthKitService as? HealthKitHeartRateService {
            PhoneSessionManager.shared.heartRateHandler = { [weak hkService] hr in
                hkService?.yield(heartRate: hr)
            }
        }
        sendWatchCommand("enterRoom", roomID: roomID)
        #endif

        // 6. Start simulated room participants (simulator only)
        #if targetEnvironment(simulator)
        startSimulatedParticipants()
        #endif

        // 7. Start star drift timer
        startStarTimer()

        Log.rooms.info("Entered room \(self.roomID)")
    }

    func exitRoom() async {
        guard let userID = currentUserID, isInRoom else { return }

        // 1. Cancel all background tasks
        observeTask?.cancel()
        heartRateTask?.cancel()
        simulationTask?.cancel()
        starTimerTask?.cancel()
        observeTask = nil
        heartRateTask = nil
        simulationTask = nil
        starTimerTask = nil

        #if targetEnvironment(simulator)
        simulatedRoomService.stopSimulation()
        simulatedParticipants = []
        #endif

        // 2. Stop HR streaming
        healthKitService.stopHeartRateStreaming()

        // 3. Tell Watch to stop HR session + disconnect handler
        #if !targetEnvironment(simulator)
        PhoneSessionManager.shared.heartRateHandler = nil
        sendWatchCommand("exitRoom")
        #endif

        // 4. Remove from Firebase
        do {
            try await roomRepository.leaveRoom(roomID: roomID, userID: userID)
        } catch {
            Log.rooms.error("Failed to leave room cleanly: \(error.localizedDescription)")
        }

        // 5. Clear state
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

        if hasNewFormations {
            // Spawn one star per new sync pair
            for _ in newFormations {
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

    // MARK: - Private: Watch Room Updates

    private func sendRoomUpdateToWatch(newSyncFormations: Bool) {
        #if !targetEnvironment(simulator)
        let graph = syncGraph
        let maxChain = graph.softClusters.map(\.chainLength).max() ?? 0
        let syncedIDs = Set(graph.softClusters.flatMap(\.memberIDs))

        let participantDicts: [[String: Any]] = allParticipantsForPlot.map { p in
            [
                "id": p.id,
                "currentHR": p.currentHR,
                "previousHR": p.previousHR,
                "color": p.color
            ]
        }

        PhoneSessionManager.shared.sendRoomUpdate(
            participants: participantDicts,
            currentUserID: currentUserID ?? "",
            maxChain: maxChain,
            syncedCount: syncedIDs.count,
            newSyncFormations: newSyncFormations
        )
        #endif
    }

    // MARK: - Private: Watch Commands

    private func sendWatchCommand(_ type: String, roomID: String? = nil) {
        var message: [String: Any] = ["type": type]
        if let roomID { message["roomID"] = roomID }

        Task {
            do {
                try await watchService.send(message: message)
                Log.rooms.debug("Sent \(type) command to Watch")
            } catch {
                Log.rooms.warning("Failed to send \(type) to Watch: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private: Observation

    private func startObservingParticipants() {
        observeTask = Task {
            for await updatedParticipants in roomRepository.observeParticipants(roomID: roomID) {
                guard !Task.isCancelled else { break }
                self.participants = updatedParticipants
                processSyncChanges()
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
                        color: assignedColor
                    )
                } catch {
                    Log.rooms.error("Failed to update HR: \(error.localizedDescription)")
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
