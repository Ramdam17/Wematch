import SwiftUI

struct GroupListView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var viewModel: GroupListViewModel?
    @State private var showCreateSheet = false
    @State private var showJoinSheet = false
    @State private var pendingAction: PendingGroupAction?

    /// A destructive group action waiting to be confirmed. Carries the kind as well as the
    /// group, because the same swipe offers Delete to an admin and Leave to everyone else.
    private struct PendingGroupAction: Identifiable {
        enum Kind: String { case delete, leave }

        let group: Group
        let kind: Kind

        var id: String { "\(kind.rawValue)-\(group.id)" }
    }

    var body: some View {
        ZStack {
            AnimatedBackground()

            if let viewModel {
                if viewModel.groups.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    groupsList(viewModel: viewModel)
                }
            }
        }
        .navigationTitle("Groups")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showJoinSheet = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("Join a group")

                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create a group")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            if let viewModel {
                CreateGroupSheet(authManager: authManager) {
                    Task { await viewModel.fetchGroups() }
                }
            }
        }
        .sheet(isPresented: $showJoinSheet) {
            JoinGroupSheet(authManager: authManager)
        }
        .task {
            if viewModel == nil {
                viewModel = GroupListViewModel(authManager: authManager)
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
        .destructiveConfirmation(
            item: $pendingAction,
            title: { $0.kind == .delete ? "Delete \($0.group.name)?" : "Leave \($0.group.name)?" },
            message: {
                $0.kind == .delete
                    ? "This permanently deletes the group and notifies all members."
                    : "You'll stop seeing this group's rooms. You can rejoin with the code."
            },
            confirmLabel: { $0.kind == .delete ? "Delete" : "Leave" },
            action: { pending in
                Task {
                    switch pending.kind {
                    case .delete: await viewModel?.deleteGroup(id: pending.group.id)
                    case .leave: await viewModel?.leaveGroup(id: pending.group.id)
                    }
                }
            }
        )
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "person.3.fill",
            iconColor: Color(hex: "C084FC"),
            title: "No Groups Yet",
            subtitle: "Create or join a group to start syncing"
        )
    }

    private func groupsList(viewModel: GroupListViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.groups) { group in
                    NavigationLink(value: group.id) {
                        GroupRowView(
                            group: group,
                            isAdmin: viewModel.isAdmin(group)
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        if viewModel.isAdmin(group) {
                            Button(role: .destructive) {
                                pendingAction = PendingGroupAction(group: group, kind: .delete)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } else {
                            Button(role: .destructive) {
                                pendingAction = PendingGroupAction(group: group, kind: .leave)
                            } label: {
                                Label("Leave", systemImage: "rectangle.portrait.and.arrow.right")
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationDestination(for: String.self) { groupID in
            if let group = viewModel.groups.first(where: { $0.id == groupID }) {
                GroupDetailView(group: group, authManager: authManager)
            }
        }
    }
}
