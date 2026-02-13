import SwiftUI

struct WatchRoomView: View {
    let heartRate: Double
    let isStreaming: Bool
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 36))
                .foregroundStyle(.pink.gradient)
                .symbolEffect(.pulse, isActive: isStreaming)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(heartRate))")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.pink)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: Int(heartRate))

                Text("BPM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if isStreaming {
                Text("Streaming")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else {
                Text("Connecting...")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }

            Button(action: onStop) {
                Text("Stop")
                    .font(.footnote.bold())
                    .foregroundStyle(.red)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}

#Preview {
    WatchRoomView(
        heartRate: 78,
        isStreaming: true,
        onStop: {}
    )
}
