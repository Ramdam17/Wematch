import SwiftUI

struct BrowseGroupsView: View {
    let authManager: AuthenticationManager

    @State private var searchText = ""
    @State private var searchResults: [Group] = []
    @State private var isSearching = false
    @State private var error: Error?
    @State private var sentRequestGroupIDs: Set<String> = []

    private let repository: any GroupRepository = CloudKitGroupRepository()

    var body: some View {
        ZStack {
            WematchTheme.backgroundGradient.ignoresSafeArea()

            if searchText.isEmpty {
                promptView
            } else if searchResults.isEmpty && !isSearching {
                noResultsView
            } else {
                resultsList
            }
        }
        .navigationTitle("Browse Groups")
        .searchable(text: $searchText, prompt: "Search by name")
        .onChange(of: searchText) {
            Task { await search() }
        }
        .alert("Error", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") { error = nil }
        } message: {
            Text(error?.localizedDescription ?? "")
        }
    }

    // MARK: - Subviews

    private var promptView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(WematchTheme.textSecondary)
            Text("Search for groups by name")
                .font(WematchTypography.body)
                .foregroundStyle(WematchTheme.textSecondary)
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 40))
                .foregroundStyle(WematchTheme.textSecondary)
            Text("No groups found")
                .font(WematchTypography.body)
                .foregroundStyle(WematchTheme.textSecondary)
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(searchResults) { group in
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.name)
                                    .font(WematchTypography.headline)
                                    .foregroundStyle(WematchTheme.textPrimary)
                                Label("\(group.memberIDs.count + 1)/20 members", systemImage: "person.2.fill")
                                    .font(WematchTypography.caption)
                                    .foregroundStyle(WematchTheme.textSecondary)
                            }

                            Spacer()

                            if sentRequestGroupIDs.contains(group.id) {
                                StatusBadge(text: "Sent", style: .pending)
                            } else {
                                Button {
                                    Task { await sendRequest(for: group) }
                                } label: {
                                    Text("Join")
                                        .font(WematchTypography.headline)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color(hex: "C084FC"))
                                        .clipShape(Capsule())
                                }
                                .disabled(group.memberIDs.count >= 20)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Actions

    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await repository.searchGroups(query: query)
        } catch {
            self.error = error
        }
    }

    private func sendRequest(for group: Group) async {
        guard let userID = authManager.currentUserID,
              let username = authManager.userProfile?.username else { return }

        do {
            try await repository.sendJoinRequest(groupID: group.id, userID: userID, username: username)
            sentRequestGroupIDs.insert(group.id)
        } catch {
            self.error = error
        }
    }
}
