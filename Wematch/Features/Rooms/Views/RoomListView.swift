import SwiftUI

struct RoomListView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var viewModel: RoomListViewModel?

    var body: some View {
        ZStack {
            AnimatedBackground()

            if let viewModel {
                if viewModel.groups.isEmpty && !viewModel.isLoading {
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
            await viewModel?.fetchGroups()
        }
        .refreshable {
            await viewModel?.fetchGroups()
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
            Text("Join a group to access its heart rate room")
                .font(WematchTypography.body)
                .foregroundStyle(WematchTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Rooms List

    private func roomsList(viewModel: RoomListViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.groups) { group in
                    NavigationLink(value: group.id) {
                        roomRow(group: group)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationDestination(for: String.self) { groupID in
            if let group = viewModel.groups.first(where: { $0.id == groupID }) {
                RoomView(
                    roomID: group.id,
                    roomName: group.name,
                    authManager: authManager
                )
            }
        }
    }

    // MARK: - Row

    private func roomRow(group: Group) -> some View {
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
}
