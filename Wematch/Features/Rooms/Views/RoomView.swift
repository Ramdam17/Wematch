import SwiftUI

struct RoomView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: RoomViewModel

    init(roomID: String, roomName: String, authManager: AuthenticationManager) {
        self._viewModel = State(
            initialValue: RoomViewModel(
                roomID: roomID,
                roomName: roomName,
                authManager: authManager
            )
        )
    }

    var body: some View {
        ZStack {
            AnimatedBackground()

            VStack(spacing: 0) {
                if viewModel.isLoading {
                    Spacer()
                    loadingView
                    Spacer()
                } else if viewModel.isInRoom {
                    roomContent
                }
            }
            .padding(.horizontal, WematchTheme.paddingSmall)
            .padding(.bottom, WematchTheme.paddingSmall)
        }
        .navigationTitle(viewModel.roomName)
        .navigationBarBackButtonHidden(viewModel.isInRoom)
        .toolbar {
            if viewModel.isInRoom {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task { await leaveRoom() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Leave")
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.enterRoom()
        }
        .alert("Error", isPresented: .init(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") {
                viewModel.error = nil
                if !viewModel.isInRoom { dismiss() }
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color(hex: "C084FC"))
            Text("Joining room...")
                .font(WematchTypography.body)
                .foregroundStyle(WematchTheme.textSecondary)
        }
    }

    // MARK: - Room Content

    private var roomContent: some View {
        VStack(spacing: WematchTheme.paddingSmall) {
            // 2D Heart Plot (fills available space)
            HeartPlotView(
                participants: viewModel.allParticipantsForPlot,
                currentUserID: viewModel.currentUserID,
                syncGraph: viewModel.syncGraph,
                activeStars: viewModel.activeStars
            )
            .frame(maxHeight: .infinity)

            // Bottom HUD bar
            bottomBar
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        GlassCard(padding: WematchTheme.paddingSmall) {
            HStack(spacing: 12) {
                // Own BPM display
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Color(hex: "FF6B9D"))
                        .symbolEffect(.pulse, isActive: viewModel.ownHeartRate > 0)
                        .font(.system(size: 16))

                    Text("\(Int(viewModel.ownHeartRate))")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(WematchTheme.primaryGradient)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: Int(viewModel.ownHeartRate))

                    Text("BPM")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(WematchTheme.textSecondary)
                }

                Spacer()

                // Sync stats
                syncStats

                // Participant count
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(WematchTheme.textSecondary)
                    Text("\(viewModel.allParticipantsForPlot.count)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(WematchTheme.textSecondary)
                }

                // Leave button
                Button {
                    Task { await leaveRoom() }
                } label: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(hex: "F87171"))
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
        }
    }

    // MARK: - Sync Stats

    private var syncStats: some View {
        let graph = viewModel.syncGraph
        let maxChain = graph.softClusters.map(\.chainLength).max() ?? 0
        let syncedIDs = Set(graph.softClusters.flatMap(\.memberIDs))

        return HStack(spacing: 10) {
            // Max chain length
            if maxChain > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "link")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "A78BFA"))
                    Text("\(maxChain)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "A78BFA"))
                }
            }

            // Synced user count
            if syncedIDs.count >= 2 {
                HStack(spacing: 3) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "34D399"))
                    Text("\(syncedIDs.count)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "34D399"))
                }
            }
        }
        .contentTransition(.numericText())
        .animation(.easeInOut(duration: 0.3), value: maxChain)
        .animation(.easeInOut(duration: 0.3), value: syncedIDs.count)
    }

    // MARK: - Actions

    private func leaveRoom() async {
        await viewModel.exitRoom()
        dismiss()
    }
}
