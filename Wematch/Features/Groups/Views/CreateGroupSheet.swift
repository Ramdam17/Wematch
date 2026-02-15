import SwiftUI

struct CreateGroupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CreateGroupViewModel
    @ScaledMetric(relativeTo: .title) private var iconSize = 40
    @ScaledMetric(relativeTo: .title) private var successIconSize = 48
    var onGroupCreated: (() -> Void)?

    init(authManager: AuthenticationManager, onGroupCreated: (() -> Void)? = nil) {
        self._viewModel = State(initialValue: CreateGroupViewModel(authManager: authManager))
        self.onGroupCreated = onGroupCreated
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()

                VStack(spacing: WematchTheme.paddingLarge) {
                    Spacer()

                    if let createdGroup = viewModel.createdGroup {
                        successView(group: createdGroup)
                    } else {
                        createFormView
                    }

                    Spacer()
                }
                .padding(.horizontal, WematchTheme.paddingLarge)
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
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

    private var createFormView: some View {
        GlassCard {
            VStack(spacing: WematchTheme.paddingMedium) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(Color(hex: "C084FC").gradient)
                    .accessibilityHidden(true)

                TextField("Group name", text: $viewModel.name)
                    .font(WematchTypography.body)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(Color(hex: "C084FC"))
                } else {
                    GradientButton("Create") {
                        Task {
                            await viewModel.createGroup()
                            if viewModel.createdGroup != nil {
                                onGroupCreated?()
                            }
                        }
                    }
                    .disabled(viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(viewModel.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }
            }
        }
    }

    private func successView(group: Group) -> some View {
        GlassCard {
            VStack(spacing: WematchTheme.paddingMedium) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: successIconSize))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)

                Text(group.name)
                    .font(WematchTypography.title2)
                    .foregroundStyle(WematchTheme.textPrimary)

                VStack(spacing: 4) {
                    Text("Join Code")
                        .font(WematchTypography.caption)
                        .foregroundStyle(WematchTheme.textSecondary)
                    Text(group.code)
                        .font(.system(.title, design: .monospaced, weight: .bold))
                        .foregroundStyle(WematchTheme.textPrimary)
                        .textSelection(.enabled)
                }

                GradientButton("Done") {
                    dismiss()
                }
            }
        }
    }
}
