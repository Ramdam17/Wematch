import SwiftUI

/// Draws a circle/ellipse around a cluster of synced hearts on the plot.
struct ClusterCircleView: View {
    let cluster: SyncCluster
    let participants: [RoomParticipant]
    let plotSize: CGSize
    let plotInsets: EdgeInsets

    /// Minimum radius for the circle (so it's visible even for two close hearts).
    private let minimumRadius: CGFloat = 30
    /// Extra padding around the outermost heart.
    private let padding: CGFloat = 22

    var body: some View {
        let geometry = clusterGeometry
        let color = clusterColor

        Circle()
            .stroke(
                color.opacity(0.5),
                style: StrokeStyle(
                    lineWidth: 1.5,
                    dash: cluster.type == .soft ? [8, 6] : []
                )
            )
            .fill(color.opacity(0.08))
            .frame(width: geometry.radius * 2, height: geometry.radius * 2)
            .position(geometry.center)
            .overlay(
                chainLengthLabel(center: geometry.center, radius: geometry.radius, color: color)
            )
            .animation(.easeInOut(duration: 0.6), value: geometry.center.x)
            .animation(.easeInOut(duration: 0.6), value: geometry.center.y)
            .animation(.easeInOut(duration: 0.6), value: geometry.radius)
    }

    // MARK: - Geometry

    private struct ClusterGeometry {
        let center: CGPoint
        let radius: CGFloat
    }

    private var clusterGeometry: ClusterGeometry {
        let memberPositions = cluster.memberIDs.compactMap { memberID -> CGPoint? in
            guard let participant = participants.first(where: { $0.id == memberID }) else { return nil }
            return PlotCoordinates.position(
                previousHR: participant.previousHR,
                currentHR: participant.currentHR,
                in: plotSize,
                insets: plotInsets
            )
        }

        guard !memberPositions.isEmpty else {
            return ClusterGeometry(center: .zero, radius: 0)
        }

        // Center = average position
        let avgX = memberPositions.map(\.x).reduce(0, +) / CGFloat(memberPositions.count)
        let avgY = memberPositions.map(\.y).reduce(0, +) / CGFloat(memberPositions.count)
        let center = CGPoint(x: avgX, y: avgY)

        // Radius = max distance from center + padding
        let maxDist = memberPositions.map { hypot($0.x - center.x, $0.y - center.y) }.max() ?? 0
        let radius = max(maxDist + padding, minimumRadius)

        return ClusterGeometry(center: center, radius: radius)
    }

    // MARK: - Color

    /// Average color from cluster members.
    private var clusterColor: Color {
        let memberColors = cluster.memberIDs.compactMap { memberID -> Color? in
            guard let participant = participants.first(where: { $0.id == memberID }) else { return nil }
            return Color(hex: participant.color)
        }

        guard !memberColors.isEmpty else { return .white }

        // Use the first member's color — averaging hex colors is complex and not worth it
        return memberColors[0]
    }

    // MARK: - Chain Length Label

    private func chainLengthLabel(center: CGPoint, radius: CGFloat, color: Color) -> some View {
        Text("\(cluster.chainLength)")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial, in: Capsule())
            .position(x: center.x, y: center.y - radius - 10)
    }
}
