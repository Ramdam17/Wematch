import SwiftUI

struct WatchHeartMarkerView: View {
    let participant: WatchParticipant
    let targetPosition: CGPoint
    let isOwnHeart: Bool

    @State private var bezierPath: WatchBezierPath
    @State private var progress: CGFloat = 1.0

    private var heartSize: CGFloat { isOwnHeart ? 16 : 12 }
    private var color: Color { Color(hex: participant.color) }

    init(participant: WatchParticipant, targetPosition: CGPoint, isOwnHeart: Bool) {
        self.participant = participant
        self.targetPosition = targetPosition
        self.isOwnHeart = isOwnHeart

        let path = WatchBezierPath(from: targetPosition, to: targetPosition,
                                   control1: targetPosition, control2: targetPosition)
        self._bezierPath = State(initialValue: path)
    }

    var body: some View {
        WatchHeartIcon(color: color, size: heartSize, showGlow: isOwnHeart)
            .watchBezierPosition(path: bezierPath, progress: progress)
            .onChange(of: targetPosition) { oldPos, newPos in
                let currentAnimatedPos = bezierPath.point(at: progress)
                let newPath = WatchBezierPath.curved(from: currentAnimatedPos, to: newPos)

                bezierPath = newPath
                progress = 0

                withAnimation(.easeInOut(duration: 0.8)) {
                    progress = 1.0
                }
            }
    }
}
