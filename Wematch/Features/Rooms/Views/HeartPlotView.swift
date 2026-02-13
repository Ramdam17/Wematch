import SwiftUI

struct HeartPlotView: View {
    let participants: [RoomParticipant]
    let currentUserID: String?

    /// Insets to leave room for axis labels
    private let plotInsets = EdgeInsets(top: 8, leading: 32, bottom: 24, trailing: 8)

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                PlotGridCanvas(insets: plotInsets)

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
                }
            }
        }
    }
}
