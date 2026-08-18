import Foundation
import OSLog

/// Generates fake multi-user heart rate data for plot testing in the simulator.
/// Each virtual participant has independent random-walk HR with mean reversion.
final class SimulatedRoomDataService: @unchecked Sendable {

    private let participantCount: Int
    private var streamTask: Task<Void, Never>?

    init(participantCount: Int = 20) {
        self.participantCount = participantCount
    }

    // MARK: - Simulated Usernames

    private static let adjectives = [
        "cosmic", "fluffy", "sparkly", "gentle", "dreamy",
        "happy", "brave", "witty", "calm", "swift",
        "bright", "wild", "clever", "warm", "bold",
        "tiny", "mighty", "silent", "golden", "mystic",
    ]

    private static let animals = [
        "narwhal", "panda", "otter", "fox", "owl",
        "dolphin", "bunny", "koala", "cat", "hawk",
        "deer", "wolf", "bear", "seal", "dove",
        "crane", "lynx", "robin", "swan", "wren",
    ]

    // MARK: - Stream

    func startSimulation() -> AsyncStream<[RoomParticipant]> {
        AsyncStream { continuation in
            let task = Task { [participantCount] in
                // Initialize participants with random HR
                // Local simulation record, not public API.
                // swiftlint:disable:next large_tuple
                var states: [(id: String, username: String, slot: HeartPaletteSlot,
                              currentHR: Double, previousHR: Double, meanTarget: Double)] = []

                for i in 0..<participantCount {
                    let adj = Self.adjectives[i % Self.adjectives.count]
                    let animal = Self.animals[i % Self.animals.count]
                    let num = String(format: "%04d", Int.random(in: 0...9999))
                    let username = "\(adj)_\(animal)\(num)"
                    let startHR = Double.random(in: 60...100)
                    let meanTarget = Double.random(in: 65...95)

                    states.append((
                        id: "sim_\(i)",
                        username: username,
                        slot: HeartPaletteSlot(index: i),
                        currentHR: startHR,
                        previousHR: startHR,
                        meanTarget: meanTarget
                    ))
                }

                Log.rooms.info("[Simulated] Room simulation started with \(participantCount) participants")

                while !Task.isCancelled {
                    // Update each participant's HR with random walk + mean reversion
                    for i in 0..<states.count {
                        let prev = states[i].currentHR
                        let drift = (states[i].meanTarget - prev) * 0.08
                        let noise = Double.random(in: -3.0...3.0)
                        let newHR = max(50, min(130, prev + drift + noise)).rounded()

                        states[i].previousHR = prev
                        states[i].currentHR = newHR
                    }

                    // Build participant array
                    let participants = states.map { state in
                        RoomParticipant(
                            id: state.id,
                            username: state.username,
                            currentHR: state.currentHR,
                            previousHR: state.previousHR,
                            slot: state.slot
                        )
                    }

                    continuation.yield(participants)
                    try? await Task.sleep(for: .seconds(1))
                }

                continuation.finish()
            }

            self.streamTask = task

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    func stopSimulation() {
        streamTask?.cancel()
        streamTask = nil
        Log.rooms.info("[Simulated] Room simulation stopped")
    }
}
