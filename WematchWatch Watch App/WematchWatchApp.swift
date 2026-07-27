import SwiftUI
import os

@main
struct WematchWatchApp: App {
    private let logger = Logger(subsystem: "com.remyramadour.Wematch.watchkitapp", category: "general")

    @State private var heartRateManager = WatchHeartRateManager()
    @State private var viewModel: WatchRoomViewModel?

    /// Last snapshot the iPhone pushed. Deliberately outlives the room: the dashboard is
    /// history, not session state, and should still be readable after leaving.
    @State private var dashboardSnapshot = WatchDashboardSnapshot.empty

    init() {
        WatchSessionManager.shared.activate()
        logger.info("WematchWatch app launched")
    }

    var body: some Scene {
        WindowGroup {
            // Two pages with a swipe between them, which is where the page dots in the
            // Watch comps come from. The left page changes with the session; the
            // dashboard is always there.
            TabView {
                livePage
                WatchDashboardView(snapshot: dashboardSnapshot)
            }
            .tabViewStyle(.page)
            .task {
                WatchSessionManager.shared.dashboardUpdateHandler = { snapshot in
                    dashboardSnapshot = snapshot
                }
                await listenForCommands()
            }
        }
    }

    /// Idle → Waiting → Room: the three honest states of the left page.
    ///
    /// Waiting is not folded into Room on purpose. The workout is running and the BPM is
    /// leaving the watch, so rendering an empty plot would make a working session look
    /// like a broken one.
    @ViewBuilder
    private var livePage: some View {
        if let viewModel, viewModel.isInRoom {
            if viewModel.participants.count > 1 {
                WatchRoomView(
                    viewModel: viewModel,
                    onStop: { stopRoom() }
                )
            } else {
                WatchWaitingView(
                    heartRate: viewModel.ownHeartRate,
                    onStop: { stopRoom() }
                )
            }
        } else {
            WatchIdleView()
        }
    }

    // MARK: - Command Listener

    private func listenForCommands() async {
        for await message in WatchSessionManager.shared.receivedMessages {
            guard let type = message["type"] as? String else { continue }

            switch type {
            case "appLaunched":
                // iPhone app became active — Watch app is now awake
                logger.debug("Watch app woken up by iPhone")
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
