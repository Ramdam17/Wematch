import SwiftUI

struct SettingsView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        ZStack {
            AnimatedBackground()

            if let viewModel {
                ScrollView {
                    VStack(spacing: WematchTheme.paddingMedium) {
                        profileSection(viewModel)
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
                    .font(.system(size: 56))
                    .foregroundStyle(Color(hex: "A78BFA").gradient)

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
