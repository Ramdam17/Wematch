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

            VStack(spacing: WematchTheme.paddingMedium) {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.isInRoom {
                    roomContent
                }
            }
            .padding()
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
        VStack(spacing: WematchTheme.paddingMedium) {
            ownHeartRateCard
            participantsSection
            Spacer()
        }
    }

    // MARK: - Own HR Card

    private var ownHeartRateCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    Text("Your Heart Rate")
                        .font(WematchTypography.caption)
                        .foregroundStyle(WematchTheme.textSecondary)
                    Spacer()
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(viewModel.ownHeartRate))")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(WematchTheme.primaryGradient)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: Int(viewModel.ownHeartRate))

                    Text("BPM")
                        .font(WematchTypography.headline)
                        .foregroundStyle(WematchTheme.textSecondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Color(hex: "FF6B9D"))
                        .symbolEffect(.pulse, isActive: viewModel.ownHeartRate > 0)

                    Text("Streaming")
                        .font(WematchTypography.caption)
                        .foregroundStyle(Color(hex: "34D399"))
                }
            }
        }
    }

    // MARK: - Participants

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("In Room (\(viewModel.participantCount))")
                .font(WematchTypography.headline)
                .foregroundStyle(WematchTheme.textPrimary)
                .padding(.horizontal, 4)

            if viewModel.otherParticipants.isEmpty {
                GlassCard {
                    HStack {
                        Image(systemName: "person.slash")
                            .foregroundStyle(WematchTheme.textSecondary)
                        Text("No other participants yet")
                            .font(WematchTypography.body)
                            .foregroundStyle(WematchTheme.textSecondary)
                        Spacer()
                    }
                }
            } else {
                ForEach(viewModel.otherParticipants) { participant in
                    participantRow(participant)
                }
            }
        }
    }

    private func participantRow(_ participant: RoomParticipant) -> some View {
        GlassCard(padding: WematchTheme.paddingSmall) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: participant.color))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .fill(Color(hex: participant.color).opacity(0.4))
                            .frame(width: 20, height: 20)
                    )

                Text(participant.username)
                    .font(WematchTypography.body)
                    .foregroundStyle(WematchTheme.textPrimary)

                Spacer()

                // Show activity indicator (not actual HR for privacy)
                Image(systemName: participant.currentHR > 0 ? "heart.fill" : "heart")
                    .foregroundStyle(Color(hex: participant.color))
                    .symbolEffect(.pulse, isActive: participant.currentHR > 0)
            }
        }
    }

    // MARK: - Actions

    private func leaveRoom() async {
        await viewModel.exitRoom()
        dismiss()
    }
}
