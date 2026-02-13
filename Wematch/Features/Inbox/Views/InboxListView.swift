import SwiftUI

struct InboxListView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var viewModel: InboxViewModel?
    @Binding var unreadCount: Int

    var body: some View {
        ZStack {
            AnimatedBackground()

            if let viewModel {
                if viewModel.messages.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    messagesList(viewModel: viewModel)
                }
            }
        }
        .navigationTitle("Inbox")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let viewModel, viewModel.unreadCount > 0 {
                    Button {
                        Task { await viewModel.markAllAsRead() }
                    } label: {
                        Image(systemName: "envelope.open")
                    }
                }
            }
        }
        .task {
            if viewModel == nil {
                viewModel = InboxViewModel(authManager: authManager)
            }
            await viewModel?.fetchMessages()
            unreadCount = viewModel?.unreadCount ?? 0
        }
        .refreshable {
            await viewModel?.fetchMessages()
            unreadCount = viewModel?.unreadCount ?? 0
        }
        .onChange(of: viewModel?.unreadCount) { _, newValue in
            unreadCount = newValue ?? 0
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

    private var emptyState: some View {
        GlassCard {
            VStack(spacing: 16) {
                Image(systemName: "envelope.open")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(hex: "FBBF24").gradient)
                Text("No Messages")
                    .font(WematchTypography.title2)
                    .foregroundStyle(WematchTheme.textPrimary)
                Text("Notifications and requests will appear here")
                    .font(WematchTypography.body)
                    .foregroundStyle(WematchTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    // MARK: - Messages List

    private func messagesList(viewModel: InboxViewModel) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.messages) { message in
                    GlassCard {
                        InboxMessageRowView(message: message) { action in
                            Task { await viewModel.performAction(action, on: message) }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await viewModel.deleteMessage(message) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding()
        }
    }
}
