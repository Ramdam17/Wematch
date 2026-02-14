import SwiftUI

struct WatchHeartPlotView: View {
    let participants: [WatchParticipant]
    let currentUserID: String?

    /// Compact insets for Watch-sized screen.
    private let plotInsets = EdgeInsets(top: 4, leading: 18, bottom: 14, trailing: 4)

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                // Grid background
                WatchPlotGridView(insets: plotInsets)

                // Heart markers (no labels, no stars, no cluster circles)
                ForEach(participants) { participant in
                    let pos = WatchPlotCoordinates.position(
                        previousHR: participant.previousHR,
                        currentHR: participant.currentHR,
                        in: size,
                        insets: plotInsets
                    )

                    WatchHeartMarkerView(
                        participant: participant,
                        targetPosition: pos,
                        isOwnHeart: participant.id == currentUserID
                    )
                }
            }
        }
    }
}
