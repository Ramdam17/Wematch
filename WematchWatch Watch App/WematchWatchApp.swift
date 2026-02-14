import SwiftUI
import os

@main
struct WematchWatchApp: App {
    private let logger = Logger(subsystem: "com.remyramadour.Wematch.watchkitapp", category: "general")

    @State private var heartRateManager = WatchHeartRateManager()
    @State private var viewModel: WatchRoomViewModel?

    init() {
        WatchSessionManager.shared.activate()
        logger.info("WematchWatch app launched")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let viewModel, viewModel.isInRoom {
                    WatchRoomView(
                        viewModel: viewModel,
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
        guard viewModel == nil || viewModel?.isInRoom == false else { return }

        let vm = WatchRoomViewModel(heartRateManager: heartRateManager)
        viewModel = vm
        vm.enterRoom()

        logger.info("Watch room started")
    }

    private func stopRoom() {
        viewModel?.exitRoom()
        viewModel = nil
        logger.info("Watch room stopped")
    }
}
