import SwiftUI

struct RoomListView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var viewModel: RoomListViewModel?

    var body: some View {
        ZStack {
            AnimatedBackground()

            if let viewModel {
                if viewModel.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    roomsList(viewModel: viewModel)
                }
            }
        }
        .navigationTitle("Rooms")
        .task {
            if viewModel == nil {
                viewModel = RoomListViewModel(authManager: authManager)
            }
            await viewModel?.fetchRooms()
        }
        .refreshable {
            await viewModel?.fetchRooms()
        }
        .alert("Error", isPresented: .init(
            get: { viewModel?.error != nil },
            set: { if !$0 { viewModel?.error = nil } }
        )) {
            Button("OK") { viewModel?.error = nil }
        } message: {
            Text(viewModel?.error?.localizedDescription ?? "")
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            HeartIcon(color: Color(hex: "FF6B9D"), size: 48, showGlow: true)
            Text("No Rooms Yet")
                .font(WematchTypography.title2)
                .foregroundStyle(WematchTheme.textPrimary)
            Text("Join a group or start a room with a friend")
                .font(WematchTypography.body)
                .foregroundStyle(WematchTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Rooms List

    private func roomsList(viewModel: RoomListViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Group rooms
                ForEach(viewModel.groups) { group in
                    NavigationLink(value: group.id) {
                        groupRoomRow(group: group)
                    }
                    .buttonStyle(.plain)
                }

                // Temporary 1-on-1 rooms
                ForEach(viewModel.temporaryRooms) { tempRoom in
                    NavigationLink(value: tempRoom.id) {
                        tempRoomRow(tempRoom: tempRoom)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationDestination(for: String.self) { roomID in
            if let group = viewModel.groups.first(where: { $0.id == roomID }) {
                RoomView(
                    roomID: group.id,
                    roomName: group.name,
                    authManager: authManager
                )
            } else if let tempRoom = viewModel.temporaryRooms.first(where: { $0.id == roomID }) {
                RoomView(
                    roomID: tempRoom.id,
                    roomName: "Room with \(tempRoom.friendUsername)",
                    authManager: authManager
                )
            }
        }
    }

    // MARK: - Group Room Row

    private func groupRoomRow(group: Group) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                HeartIcon(
                    color: Color(hex: "C084FC"),
                    size: 32,
                    showGlow: false
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(WematchTypography.headline)
                        .foregroundStyle(WematchTheme.textPrimary)
                    Text("\(group.memberIDs.count) members")
                        .font(WematchTypography.caption)
                        .foregroundStyle(WematchTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "heart.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        WematchTheme.primaryGradient
                    )
            }
        }
    }

    // MARK: - Temp Room Row

    private func tempRoomRow(tempRoom: TemporaryRoom) -> some View {
        GlassCard {
            HStack(spacing: 12) {
                HeartIcon(
                    color: Color(hex: "EC4899"),
                    size: 32,
                    showGlow: false
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(tempRoom.friendUsername)
                        .font(WematchTypography.headline)
                        .foregroundStyle(WematchTheme.textPrimary)
                    Text("1-on-1 Room")
                        .font(WematchTypography.caption)
                        .foregroundStyle(WematchTheme.textSecondary)
                }

                Spacer()

                StatusBadge(text: "1-on-1", style: .custom(Color(hex: "EC4899")))
            }
        }
    }
}
