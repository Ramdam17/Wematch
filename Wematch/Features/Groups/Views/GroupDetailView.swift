import SwiftUI

struct GroupDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: GroupDetailViewModel
    @State private var showDeleteConfirmation = false
    @State private var navigateToRoom = false
    private let authManager: AuthenticationManager

    init(group: Group, authManager: AuthenticationManager) {
        self.authManager = authManager
        self._viewModel = State(
            initialValue: GroupDetailViewModel(group: group, authManager: authManager)
        )
    }

    var body: some View {
        ZStack {
            AnimatedBackground()

            ScrollView {
                VStack(spacing: WematchTheme.paddingMedium) {
                    headerSection
                    membersSection

                    if viewModel.isAdmin && !viewModel.joinRequests.isEmpty {
                        requestsSection
                    }

                    enterRoomSection
                    actionsSection
                }
                .padding()
            }
        }
        .navigationTitle(viewModel.group.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchDetails()
        }
        .onChange(of: viewModel.isDeleted) {
            if viewModel.isDeleted { dismiss() }
        }
        .onChange(of: viewModel.hasLeft) {
            if viewModel.hasLeft { dismiss() }
        }
        .confirmationDialog("Delete Group", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteGroup() }
            }
        } message: {
            Text("This will permanently delete the group and notify all members.")
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

    // MARK: - Header

    private var headerSection: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.group.name)
                            .font(WematchTypography.title2)
                            .foregroundStyle(WematchTheme.textPrimary)

                        Text("\(viewModel.memberCount)/20 members")
                            .font(WematchTypography.caption)
                            .foregroundStyle(WematchTheme.textSecondary)
                    }

                    Spacer()

                    StatusBadge(
                        text: viewModel.isAdmin ? "Admin" : "Member",
                        style: viewModel.isAdmin ? .admin : .member
                    )
                }

                HStack {
                    Text("Join Code")
                        .font(WematchTypography.caption)
                        .foregroundStyle(WematchTheme.textSecondary)
                    Spacer()
                    Text(viewModel.group.code)
                        .font(.system(.body, design: .monospaced, weight: .bold))
                        .foregroundStyle(WematchTheme.textPrimary)
                        .textSelection(.enabled)

                    Button {
                        UIPasteboard.general.string = viewModel.group.code
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(Color(hex: "C084FC"))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Members

    private var membersSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Members")
                    .font(WematchTypography.headline)
                    .foregroundStyle(WematchTheme.textPrimary)

                ForEach(viewModel.memberProfiles) { profile in
                    let isProfileAdmin = profile.id == viewModel.group.adminID
                    let canRemove = viewModel.isAdmin && !isProfileAdmin
                    MemberRowView(
                        profile: profile,
                        isGroupAdmin: isProfileAdmin,
                        canRemove: canRemove
                    ) {
                        Task { await viewModel.removeMember(userID: profile.id) }
                    }

                    if profile.id != viewModel.memberProfiles.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Join Requests

    private var requestsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pending Requests")
                        .font(WematchTypography.headline)
                        .foregroundStyle(WematchTheme.textPrimary)

                    Spacer()

                    StatusBadge(text: "\(viewModel.joinRequests.count)", style: .pending)
                }

                ForEach(viewModel.joinRequests) { request in
                    JoinRequestRowView(request: request) {
                        Task { await viewModel.acceptRequest(request) }
                    } onDecline: {
                        Task { await viewModel.declineRequest(request) }
                    }

                    if request.id != viewModel.joinRequests.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Enter Room

    private var enterRoomSection: some View {
        NavigationLink(destination: RoomView(
            roomID: viewModel.group.id,
            roomName: viewModel.group.name,
            authManager: authManager
        )) {
            HStack(spacing: 8) {
                Image(systemName: "heart.circle.fill")
                Text("Enter Room")
            }
            .font(WematchTypography.headline)
            .foregroundStyle(WematchTheme.textOnColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, WematchTheme.paddingLarge)
            .background(WematchTheme.primaryGradient)
            .clipShape(Capsule())
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        SwiftUI.Group {
            if viewModel.isAdmin {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Group")
                    }
                    .font(WematchTypography.headline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.red.opacity(0.3), lineWidth: 1))
                }
            } else {
                Button(role: .destructive) {
                    Task { await viewModel.leaveGroup() }
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Leave Group")
                    }
                    .font(WematchTypography.headline)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.orange.opacity(0.3), lineWidth: 1))
                }
            }
        }
    }
}
