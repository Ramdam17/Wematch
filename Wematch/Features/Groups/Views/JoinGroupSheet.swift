import SwiftUI

struct JoinGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    let authManager: AuthenticationManager

    @ScaledMetric(relativeTo: .title) private var iconSize = 40
    @ScaledMetric(relativeTo: .title) private var successIconSize = 48
    @State private var joinCode = ""
    @State private var isLoading = false
    @State private var error: Error?
    @State private var requestSent = false

    private let repository: any GroupRepository = CloudKitGroupRepository()

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()

                VStack(spacing: WematchTheme.paddingLarge) {
                    Spacer()

                    if requestSent {
                        successView
                    } else {
                        enterCodeView
                    }

                    Spacer()

                    NavigationLink {
                        BrowseGroupsView(authManager: authManager)
                    } label: {
                        Label("Browse Groups", systemImage: "magnifyingglass")
                            .font(WematchTypography.headline)
                            .foregroundStyle(Color(hex: "C084FC"))
                    }
                    .padding(.bottom, WematchTheme.paddingLarge)
                }
                .padding(.horizontal, WematchTheme.paddingLarge)
            }
            .navigationTitle("Join Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
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
    }

    // MARK: - Subviews

    private var enterCodeView: some View {
        GlassCard {
            VStack(spacing: WematchTheme.paddingMedium) {
                Image(systemName: "number")
                    .font(.system(size: iconSize))
                    .foregroundStyle(Color(hex: "67E8F9").gradient)
                    .accessibilityHidden(true)

                Text("Enter a group code")
                    .font(WematchTypography.headline)
                    .foregroundStyle(WematchTheme.textPrimary)

                TextField("Code", text: $joinCode)
                    .font(.system(.title2, design: .monospaced, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)

                if isLoading {
                    ProgressView()
                        .tint(Color(hex: "C084FC"))
                } else {
                    GradientButton("Join") {
                        Task { await sendJoinRequest() }
                    }
                    .disabled(joinCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 6)
                    .opacity(joinCode.trimmingCharacters(in: .whitespacesAndNewlines).count < 6 ? 0.5 : 1)
                }
            }
        }
    }

    private var successView: some View {
        GlassCard {
            VStack(spacing: WematchTheme.paddingMedium) {
                Image(systemName: "paperplane.circle.fill")
                    .font(.system(size: successIconSize))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)

                Text("Request Sent!")
                    .font(WematchTypography.title2)
                    .foregroundStyle(WematchTheme.textPrimary)

                Text("The group admin will review your request.")
                    .font(WematchTypography.body)
                    .foregroundStyle(WematchTheme.textSecondary)
                    .multilineTextAlignment(.center)

                GradientButton("Done") {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Actions

    private func sendJoinRequest() async {
        guard let userID = authManager.currentUserID,
              let username = authManager.userProfile?.username else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            guard let group = try await repository.fetchGroup(byCode: joinCode.uppercased()) else {
                throw GroupError.codeNotFound
            }
            try await repository.sendJoinRequest(groupID: group.id, userID: userID, username: username)
            requestSent = true
        } catch {
            self.error = error
        }
    }
}
