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

        Log.rooms.info("Entered room \(self.roomID)")
    }

    func exitRoom() async {
        guard let userID = currentUserID, isInRoom else { return }

        // 1. Cancel all background tasks
        observeTask?.cancel()
        heartRateTask?.cancel()
        simulationTask?.cancel()
        observeTask = nil
        heartRateTask = nil
        simulationTask = nil

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

        Log.rooms.info("Exited room \(self.roomID)")
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
            }
        }
    }
    #endif
}
