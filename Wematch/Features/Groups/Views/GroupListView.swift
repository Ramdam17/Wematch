import SwiftUI

struct GroupListView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var viewModel: GroupListViewModel?
    @State private var showCreateSheet = false
    @State private var showJoinSheet = false
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
                                Task { await viewModel.deleteGroup(id: group.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } else {
                            Button(role: .destructive) {
                                Task { await viewModel.leaveGroup(id: group.id) }
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
