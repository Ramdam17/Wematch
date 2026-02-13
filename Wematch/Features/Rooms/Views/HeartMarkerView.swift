import SwiftUI

struct HeartMarkerView: View {
    let participant: RoomParticipant
    let targetPosition: CGPoint
    let isOwnHeart: Bool

    @State private var bezierPath: BezierPath
    @State private var progress: CGFloat = 1.0
    @State private var currentPosition: CGPoint

    private var heartSize: CGFloat { isOwnHeart ? 28 : 20 }
    private var color: Color { Color(hex: participant.color) }

    init(participant: RoomParticipant, targetPosition: CGPoint, isOwnHeart: Bool) {
        self.participant = participant
        self.targetPosition = targetPosition
        self.isOwnHeart = isOwnHeart

        let path = BezierPath(from: targetPosition, to: targetPosition,
                              control1: targetPosition, control2: targetPosition)
        self._bezierPath = State(initialValue: path)
        self._currentPosition = State(initialValue: targetPosition)
    }

    var body: some View {
        VStack(spacing: 2) {
            HeartIcon(color: color, size: heartSize, showGlow: isOwnHeart)

            Text(participant.username)
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .foregroundStyle(color.opacity(0.8))
                .lineLimit(1)
                .frame(maxWidth: 60)
        }
        .bezierPosition(path: bezierPath, progress: progress)
        .onChange(of: targetPosition) { oldPos, newPos in
            // Compute current animated position as the start of the new curve
            let currentAnimatedPos = bezierPath.point(at: progress)
            let newPath = BezierPath.curved(from: currentAnimatedPos, to: newPos)

            bezierPath = newPath
            progress = 0

            withAnimation(.easeInOut(duration: 0.8)) {
                progress = 1.0
            }

            currentPosition = newPos
        }
    }
}
