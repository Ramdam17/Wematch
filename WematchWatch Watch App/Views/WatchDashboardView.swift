import SwiftUI

/// "Together" — four lifetime numbers, computed on the iPhone and pushed over.
///
/// Every value arrives resolved (see `WatchDashboardSnapshot`). Nothing is aggregated
/// here, so the screen renders identically whether the phone is reachable or not; it just
/// shows the last snapshot that landed.
struct WatchDashboardView: View {

    let snapshot: WatchDashboardSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Together")
                    .font(.headline)
                    .foregroundStyle(WatchTheme.textPrimary)

                if snapshot.hasHistory {
                    metrics
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
        .background(WatchTheme.background)
    }

    // MARK: - Metrics

    @ViewBuilder
    private var metrics: some View {
        if let name = snapshot.bestPartnerName {
            MetricRow(
                systemImage: "heart.fill",
                tint: partnerColor,
                label: "Best friend",
                value: name,
                valueFont: .system(size: 15, weight: .semibold, design: .rounded),
                spokenValue: name
            )
        }

        MetricRow(
            systemImage: "sparkles",
            tint: WatchTheme.starGold,
            label: "Stars made",
            value: "\(snapshot.starsMade)",
            spokenValue: "\(snapshot.starsMade)"
        )

        MetricRow(
            systemImage: "clock.fill",
            tint: WatchTheme.syncGreen,
            label: "Time in sync",
            value: snapshot.connectedDurationText,
            spokenValue: snapshot.connectedDurationSpoken
        )

        MetricRow(
            systemImage: "person.3.fill",
            tint: WatchTheme.clusterPurple,
            label: "Biggest cluster",
            // "x5" reads as a multiplier, which is the point: it counts the whole
            // cluster, the user included.
            value: "x\(snapshot.biggestCluster)",
            spokenValue: "\(snapshot.biggestCluster) people"
        )
    }

    /// The partner's own heart colour, resolved from the slot the phone sent rather than
    /// a hex — the same wire discipline as the participants on the plot.
    private var partnerColor: Color {
        snapshot.bestPartnerSlot.map { WatchHeartPalette.color(slot: $0) } ?? WatchTheme.brandHeart
    }

    private var emptyState: some View {
        Text("No sync history yet. Join a room and find someone's rhythm.")
            .font(.caption2)
            .foregroundStyle(WatchTheme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("No sync history yet")
    }
}

// MARK: - Metric Row

private struct MetricRow: View {

    let systemImage: String
    let tint: Color
    let label: String
    let value: String
    var valueFont: Font = .system(size: 20, weight: .bold, design: .rounded)
    let spokenValue: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .foregroundStyle(tint)
                .frame(width: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(WatchTheme.textSecondary)

                Text(value)
                    .font(valueFont)
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WatchTheme.glassFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        // One element per metric, spoken as "Stars made, 128" — VoiceOver parity with the
        // iPhone HUD, which is a v1 requirement (audit G3).
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(spokenValue)
    }
}

// MARK: - Previews

#Preview("With history") {
    WatchDashboardView(snapshot: WatchDashboardSnapshot(
        bestPartnerName: "brave_otter",
        bestPartnerSlot: 7,
        starsMade: 128,
        connectedSeconds: 13_320,
        biggestCluster: 5
    ))
}

#Preview("Nothing yet") {
    WatchDashboardView(snapshot: .empty)
}
