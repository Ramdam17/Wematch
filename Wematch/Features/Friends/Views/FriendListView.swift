import SwiftUI

enum FriendTab: String, CaseIterable {
    case friends = "Friends"
    case requests = "Requests"
}

struct FriendListView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var viewModel: FriendListViewModel?
    @State private var selectedTab: FriendTab = .friends
    @State private var showSearchSheet = false
    @State private var showRoom = false
    @State private var roomNavInfo: (roomID: String, roomName: String)?
    var body: some View {
        ZStack {
            AnimatedBackground()

            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    ForEach(FriendTab.allCases, id: \.self) { tab in
                        if tab == .requests, let vm = viewModel, vm.incomingCount > 0 {
                            Text("\(tab.rawValue) (\(vm.incomingCount))").tag(tab)
                        } else {
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                switch selectedTab {
                case .friends:
                    friendsContent
                case .requests:
                    requestsContent
                }
            }
        }
        .navigationTitle("Friends")
        .navigationDestination(isPresented: $showRoom) {
            if let info = roomNavInfo {
                RoomView(roomID: info.roomID, roomName: info.roomName, authManager: authManager)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSearchSheet = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
                .accessibilityLabel("Add a friend")
            }
        }
        .sheet(isPresented: $showSearchSheet) {
            if viewModel != nil {
                UserSearchSheet(authManager: authManager)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = FriendListViewModel(authManager: authManager)
            }
            await viewModel?.fetchAll()
        }
        .refreshable {
            await viewModel?.fetchAll()
        }
        .onChange(of: viewModel?.pendingRoomNavigation?.roomID) { _, newValue in
            if let nav = viewModel?.pendingRoomNavigation {
                roomNavInfo = nav
                showRoom = true
                viewModel?.pendingRoomNavigation = nil
            }
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

    // MARK: - Friends Tab

    @ViewBuilder
    private var friendsContent: some View {
        if let viewModel, viewModel.friends.isEmpty && !viewModel.isLoading {
            Spacer()
            EmptyStateView(
                icon: "person.2.fill",
                iconColor: Color(hex: "67E8F9"),
                title: "No Friends Yet",
                subtitle: "Tap + to find and add friends"
            )
            Spacer()
        } else if let viewModel {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.friends) { friendship in
                        if let profile = viewModel.friendProfile(for: friendship) {
                            FriendRowView(profile: profile) {
                                Task { await viewModel.startRoom(with: profile) }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    Task { await viewModel.removeFriend(friendshipID: friendship.id) }
                                } label: {
                                    Label("Remove", systemImage: "person.badge.minus")
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Requests Tab

    @ViewBuilder
    private var requestsContent: some View {
        if let viewModel, viewModel.incomingRequests.isEmpty && viewModel.outgoingRequests.isEmpty {
            Spacer()
            EmptyStateView(
                icon: "envelope.open",
                iconColor: WematchTheme.textSecondary,
                title: "No Pending Requests"
            )
            Spacer()
        } else if let viewModel {
            ScrollView {
                VStack(spacing: WematchTheme.paddingMedium) {
                    if !viewModel.incomingRequests.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Incoming")
                                    .font(WematchTypography.headline)
                                    .foregroundStyle(WematchTheme.textPrimary)

                                ForEach(viewModel.incomingRequests) { request in
                                    FriendRequestRowView(
                                        request: request,
                                        isIncoming: true,
                                        onAccept: { Task { await viewModel.acceptRequest(request) } },
                                        onDecline: { Task { await viewModel.declineRequest(request) } }
                                    )

                                    if request.id != viewModel.incomingRequests.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }

                    if !viewModel.outgoingRequests.isEmpty {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Outgoing")
                                    .font(WematchTypography.headline)
                                    .foregroundStyle(WematchTheme.textPrimary)

                                ForEach(viewModel.outgoingRequests) { request in
                                    FriendRequestRowView(
                                        request: request,
                                        isIncoming: false,
                                        onCancel: { Task { await viewModel.cancelRequest(request) } }
                                    )

                                    if request.id != viewModel.outgoingRequests.last?.id {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
}
