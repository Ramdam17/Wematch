import SwiftUI

struct UserSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: UserSearchViewModel
    init(authManager: AuthenticationManager) {
        self._viewModel = State(initialValue: UserSearchViewModel(authManager: authManager))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()

                if viewModel.searchText.isEmpty {
                    promptView
                } else if viewModel.isSearching {
                    ProgressView()
                        .tint(Color(hex: "C084FC"))
                } else if viewModel.results.isEmpty {
                    noResultsView
                } else {
                    resultsList
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "Search by username")
            .onChange(of: viewModel.searchText) {
                Task { viewModel.search() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                await viewModel.loadContext()
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "")
            }
        }
    }

    // MARK: - Subviews

    private var promptView: some View {
        EmptyStateView(
            icon: "magnifyingglass",
            iconColor: WematchTheme.textSecondary,
            title: "Search for users by username"
        )
    }

    private var noResultsView: some View {
        EmptyStateView(
            icon: "person.slash",
            iconColor: WematchTheme.textSecondary,
            title: "No users found"
        )
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.results) { user in
                    GlassCard {
                        UserSearchRowView(
                            profile: user,
                            status: viewModel.status(for: user.id)
                        ) {
                            Task { await viewModel.sendRequest(to: user) }
                        }
                    }
                }
            }
            .padding()
        }
    }
}
