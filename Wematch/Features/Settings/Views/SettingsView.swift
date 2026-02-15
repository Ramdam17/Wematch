import SwiftUI

struct SettingsView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var viewModel: SettingsViewModel?
    @ScaledMetric(relativeTo: .largeTitle) private var profileIconSize = 56
    @ScaledMetric(relativeTo: .title) private var dashboardIconSize = 24

    var body: some View {
        ZStack {
            AnimatedBackground()

            if let viewModel {
                ScrollView {
                    VStack(spacing: WematchTheme.paddingMedium) {
                        profileSection(viewModel)
                        dashboardSection()
                        accountSection(viewModel)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Settings")
        .task {
            if viewModel == nil {
                viewModel = SettingsViewModel(authManager: authManager)
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
        .alert("Delete Account", isPresented: .init(
            get: { viewModel?.showDeleteConfirmation == true },
            set: { if !$0 { viewModel?.showDeleteConfirmation = false } }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                Task { await viewModel?.deleteAccount() }
            }
        } message: {
            Text("This will permanently delete your profile, groups, friends, and all associated data. This action cannot be undone.")
        }
        .overlay {
            if viewModel?.isDeletingAccount == true {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    GlassCard {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Deleting account...")
                                .font(WematchTypography.headline)
                                .foregroundStyle(WematchTheme.textPrimary)
                        }
                        .padding()
                    }
                    .frame(width: 200)
                }
            }
        }
    }

    // MARK: - Sections

    private func profileSection(_ viewModel: SettingsViewModel) -> some View {
        GlassCard {
            VStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: profileIconSize))
                    .foregroundStyle(Color(hex: "A78BFA").gradient)
                    .accessibilityHidden(true)

                Text(viewModel.username)
                    .font(WematchTypography.title2)
                    .foregroundStyle(WematchTheme.textPrimary)

                if !viewModel.memberSince.isEmpty {
                    Text("Member since \(viewModel.memberSince)")
                        .font(WematchTypography.caption)
                        .foregroundStyle(WematchTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func dashboardSection() -> some View {
        NavigationLink {
            DashboardPlaceholderView()
        } label: {
            GlassCard {
                HStack {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: dashboardIconSize))
                        .foregroundStyle(Color(hex: "F472B6").gradient)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dashboard")
                            .font(WematchTypography.headline)
                            .foregroundStyle(WematchTheme.textPrimary)
                        Text("Coming Soon")
                            .font(WematchTypography.caption)
                            .foregroundStyle(WematchTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(WematchTypography.caption)
                        .foregroundStyle(WematchTheme.textSecondary)
                }
            }
        }
    }

    private func accountSection(_ viewModel: SettingsViewModel) -> some View {
        VStack(spacing: 12) {
            GradientButton("Sign Out") {
                Task { await viewModel.signOut() }
            }

            Button {
                viewModel.showDeleteConfirmation = true
            } label: {
                Text("Delete Account")
                    .font(WematchTypography.headline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, WematchTheme.paddingLarge)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
    }
}
