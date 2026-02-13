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
                WematchTheme.backgroundGradient.ignoresSafeArea()

                if viewModel.searchText.isEmpty {
                    promptView
                } else if viewModel.results.isEmpty && !viewModel.isSearching {
                    noResultsView
                } else {
                    resultsList
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $viewModel.searchText, prompt: "Search by username")
            .onChange(of: viewModel.searchText) {
                Task { await viewModel.search() }
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
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(WematchTheme.textSecondary)
            Text("Search for users by username")
                .font(WematchTypography.body)
                .foregroundStyle(WematchTheme.textSecondary)
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.slash")
                .font(.system(size: 40))
                .foregroundStyle(WematchTheme.textSecondary)
            Text("No users found")
                .font(WematchTypography.body)
                .foregroundStyle(WematchTheme.textSecondary)
        }
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
