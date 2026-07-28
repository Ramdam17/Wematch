import SwiftUI

/// The user's sync history.
///
/// Deliberately narrow. "Real dashboards" sits in the plan's Phase 3+ backlog and this is
/// not it — no charts, no trends, no session list. It shows the numbers the recording
/// already produces, using the same vocabulary as the Watch, because leaving a screen
/// saying "Coming Soon" over data that exists is its own kind of lie.
///
/// There is no Figma comp for this screen; the layout is assembled from the library's
/// existing pieces rather than invented.
struct DashboardView: View {

    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.featureFlagProvider) private var featureFlags
    @State private var viewModel: DashboardViewModel?

    var body: some View {
        ZStack {
            AnimatedBackground()

            switch viewModel?.state {
            case .loaded(let metrics):
                DashboardContentView(
                    metrics: metrics,
                    partnerName: viewModel?.bestPartnerName,
                    partnerColor: partnerColor
                )
            case .empty:
                emptyState
            case .unavailable:
                EmptyStateView(
                    icon: "lock.fill",
                    iconColor: WematchTheme.textSecondary,
                    title: "Not available",
                    subtitle: "The dashboard is turned off for this build."
                )
                .padding()
            case .loading, nil:
                LoadingState(message: "Reading your history…")
            }
        }
        .navigationTitle("Dashboard")
        .task {
            if viewModel == nil {
                viewModel = DashboardViewModel(
                    authManager: authManager,
                    featureFlags: featureFlags
                )
            }
            await viewModel?.load()
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

    // MARK: - States

    private var emptyState: some View {
        EmptyStateView(
            icon: "heart.text.square",
            iconColor: WematchTheme.brandHeart,
            title: "No history yet",
            subtitle: "Join a room and find someone's rhythm. Your synced moments land here."
        )
        .padding()
    }

    /// The best friend's own heart colour, from their slot — never a stored hex.
    private var partnerColor: Color {
        viewModel?.bestPartnerSlot.map(WematchTheme.heartColor(for:)) ?? WematchTheme.brandHeart
    }
}

// MARK: - Metric Row

private struct MetricRow: View {

    let leading: AnyView
    let label: String
    let value: String
    let spokenValue: String

    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 24

    init(icon: String, tint: Color, label: String, value: String, spokenValue: String) {
        self.init(
            leading: AnyView(
                Image(systemName: icon)
                    .font(WematchTypography.body)
                    .foregroundStyle(tint)
            ),
            label: label, value: value, spokenValue: spokenValue
        )
    }

    init(leading: AnyView, label: String, value: String, spokenValue: String) {
        self.leading = leading
        self.label = label
        self.value = value
        self.spokenValue = spokenValue
    }

    var body: some View {
        HStack(spacing: 12) {
            leading
                .frame(width: iconWidth)
                .accessibilityHidden(true)

            Text(label)
                .font(WematchTypography.body)
                .foregroundStyle(WematchTheme.textSecondary)

            Spacer(minLength: 8)

            Text(value)
                .font(WematchTypography.bodyEmphasized)
                .foregroundStyle(WematchTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        // Read as "Stars made, 128" rather than three fragments.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(spokenValue)
    }
}

// MARK: - Content

/// The cards, split out from `DashboardView` so they can be previewed: the full screen
/// needs an `AuthenticationManager` from the environment, and the app cannot get past
/// Sign In in the simulator.
struct DashboardContentView: View {

    let metrics: DashboardMetrics
    let partnerName: String?
    let partnerColor: Color

    var body: some View {
        ScrollView {
            VStack(spacing: WematchTheme.paddingMedium) {
                togetherCard
                roomsCard
            }
            .padding()
        }
    }

    // MARK: - Cards

    private var togetherCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Together")

                if let partnerName {
                    MetricRow(
                        // The partner's own hue, drawn through HeartIcon so it keeps the
                        // marker outline: a raw palette fill measures about 2.8:1 on a
                        // pale background and reads as a rendering artefact rather than
                        // a deliberate colour.
                        leading: AnyView(
                            HeartIcon(color: partnerColor, size: 15, showOutline: true)
                        ),
                        label: "Best friend",
                        value: partnerName,
                        spokenValue: partnerName
                    )
                }

                MetricRow(
                    icon: "sparkles",
                    tint: WematchTheme.tintPending.on,
                    label: "Stars made",
                    value: "\(metrics.totalStars)",
                    spokenValue: "\(metrics.totalStars)"
                )

                MetricRow(
                    icon: "clock.fill",
                    tint: WematchTheme.tintSuccess.on,
                    label: "Time in sync",
                    value: DashboardViewModel.durationText(metrics.connectedDuration),
                    spokenValue: DashboardViewModel.durationSpoken(metrics.connectedDuration)
                )

                MetricRow(
                    icon: "person.3.fill",
                    tint: WematchTheme.tintAccent.on,
                    label: "Biggest cluster",
                    value: "x\(metrics.maxClusterSize)",
                    spokenValue: "\(metrics.maxClusterSize) people"
                )

                MetricRow(
                    icon: "person.2.fill",
                    tint: WematchTheme.tintInfo.on,
                    label: "People synced with",
                    value: "\(metrics.uniqueSyncPartners)",
                    spokenValue: "\(metrics.uniqueSyncPartners)"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var roomsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Your rooms")

                MetricRow(
                    icon: "door.left.hand.open",
                    tint: WematchTheme.tintInfo.on,
                    label: "Sessions",
                    value: "\(metrics.totalSessions)",
                    spokenValue: "\(metrics.totalSessions)"
                )

                MetricRow(
                    icon: "hourglass",
                    tint: WematchTheme.tintAccent.on,
                    label: "Total time",
                    value: DashboardViewModel.durationText(metrics.totalSessionDuration),
                    spokenValue: DashboardViewModel.durationSpoken(metrics.totalSessionDuration)
                )

                MetricRow(
                    icon: "chart.bar.fill",
                    tint: WematchTheme.tintPending.on,
                    label: "Average session",
                    value: DashboardViewModel.durationText(metrics.averageSessionDuration),
                    spokenValue: DashboardViewModel.durationSpoken(metrics.averageSessionDuration)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(WematchTypography.title3)
            .foregroundStyle(WematchTheme.textPrimary)
    }

}

// MARK: - Previews

private extension DashboardMetrics {
    static let sample = DashboardMetrics(
        totalSessions: 23,
        totalSessionDuration: 41_400,
        averageSessionDuration: 1_800,
        totalSyncEvents: 87,
        totalSyncDuration: 26_400,
        connectedDuration: 13_320,
        longestSyncDuration: 900,
        uniqueSyncPartners: 9,
        bestPartner: SyncPartnerTotal(userID: "a", duration: 7_200),
        totalStars: 128,
        maxClusterSize: 5
    )
}

#Preview("Pastel Light") {
    ZStack {
        WematchTheme.backgroundGradient.ignoresSafeArea()
        DashboardContentView(
            metrics: .sample,
            partnerName: "brave_otter",
            partnerColor: WematchTheme.heartColor(for: HeartPaletteSlot(index: 7))
        )
    }
    .environment(\.colorScheme, .light)
}

#Preview("Dark Cosmic") {
    ZStack {
        WematchTheme.backgroundGradient.ignoresSafeArea()
        DashboardContentView(
            metrics: .sample,
            partnerName: "brave_otter",
            partnerColor: WematchTheme.heartColor(for: HeartPaletteSlot(index: 7))
        )
    }
    .environment(\.colorScheme, .dark)
}
