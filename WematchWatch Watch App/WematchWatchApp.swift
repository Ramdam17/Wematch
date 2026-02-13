import SwiftUI
import os

@main
struct WematchWatchApp: App {
    private let logger = Logger(subsystem: "com.remyramadour.Wematch.watchkitapp", category: "general")

    @State private var heartRateManager = WatchHeartRateManager()
    @State private var currentHR: Double = 0
    @State private var isInRoom = false
    @State private var streamTask: Task<Void, Never>?

    init() {
        WatchSessionManager.shared.activate()
        logger.info("WematchWatch app launched")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isInRoom {
                    WatchRoomView(
                        heartRate: currentHR,
                        isStreaming: heartRateManager.isStreaming,
                        onStop: { stopRoom() }
                    )
                } else {
                    WatchPlaceholderView()
                }
            }
            .task {
                await listenForCommands()
            }
        }
    }

    // MARK: - Command Listener

    private func listenForCommands() async {
        for await message in WatchSessionManager.shared.receivedMessages {
            guard let type = message["type"] as? String else { continue }

            switch type {
            case "enterRoom":
                startRoom()
            case "exitRoom":
                stopRoom()
            default:
                break
            }
        }
    }

    // MARK: - Room Lifecycle

    private func startRoom() {
        guard !isInRoom else { return }
        isInRoom = true

        streamTask = Task {
            // Request HealthKit auth if needed
            if !heartRateManager.isAuthorized {
                do {
                    try await heartRateManager.requestAuthorization()
                } catch {
                    logger.error("HealthKit auth failed: \(error.localizedDescription)")
                    isInRoom = false
                    return
                }
            }

            // Start streaming HR
            for await hr in heartRateManager.startStreaming() {
                guard !Task.isCancelled else { break }
                currentHR = hr
                WatchSessionManager.shared.sendHeartRate(hr)
            }
        }

        logger.info("Watch room started")
    }

    private func stopRoom() {
        streamTask?.cancel()
        streamTask = nil
        heartRateManager.stopStreaming()
        currentHR = 0
        isInRoom = false
        logger.info("Watch room stopped")
    }
}
