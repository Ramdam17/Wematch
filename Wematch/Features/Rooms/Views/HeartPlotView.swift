import SwiftUI

struct HeartPlotView: View {
    let participants: [RoomParticipant]
    let currentUserID: String?
    let syncGraph: SyncGraph
    let activeStars: [SyncStar]

    /// Insets to leave room for axis labels
    private let plotInsets = EdgeInsets(top: 8, leading: 32, bottom: 24, trailing: 8)

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                // Layer 1: Static grid
                PlotGridCanvas(insets: plotInsets)
                    .accessibilityHidden(true)

                // Layer 2: Stars (behind hearts)
                ForEach(activeStars) { star in
                    SyncStarView(star: star)
                        .position(
                            x: star.position.x * size.width,
                            y: star.position.y * size.height
                        )
                        .accessibilityHidden(true)
                }

                // Layer 3: Cluster circles
                ForEach(syncGraph.softClusters) { cluster in
                    ClusterCircleView(
                        cluster: cluster,
                        participants: participants,
                        plotSize: size,
                        plotInsets: plotInsets
                    )
                    .accessibilityHidden(true)
                }

                ForEach(syncGraph.hardClusters) { cluster in
                    ClusterCircleView(
                        cluster: cluster,
                        participants: participants,
                        plotSize: size,
                        plotInsets: plotInsets
                    )
                    .accessibilityHidden(true)
                }

                // Layer 4: Heart markers (on top)
                ForEach(participants) { participant in
                    let pos = PlotCoordinates.position(
                        previousHR: participant.previousHR,
                        currentHR: participant.currentHR,
                        in: size,
                        insets: plotInsets
                    )

                    HeartMarkerView(
                        participant: participant,
                        targetPosition: pos,
                        isOwnHeart: participant.id == currentUserID
                    )
                    .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Heart rate plot with \(participants.count) participants")
        }
    }
}
