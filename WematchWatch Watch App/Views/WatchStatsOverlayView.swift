import SwiftUI

struct WatchStatsOverlayView: View {
    let heartRate: Double
    let maxChain: Int
    let syncedCount: Int
    let participantCount: Int

    var body: some View {
        HStack(spacing: 8) {
            // BPM
            HStack(spacing: 3) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.pink)
                    .symbolEffect(.pulse, isActive: heartRate > 0)

                Text("\(Int(heartRate))")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.pink)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: Int(heartRate))
            }

            Spacer()

            // Chain length
            if maxChain > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "link")
                        .font(.system(size: 8))
                        .foregroundStyle(Color(hex: "A78BFA"))
                    Text("\(maxChain)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "A78BFA"))
                }
            }

            // Synced count
            if syncedCount >= 2 {
                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color(hex: "34D399"))
                    Text("\(syncedCount)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: "34D399"))
                }
            }

            // Participant count
            HStack(spacing: 2) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                Text("\(participantCount)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .contentTransition(.numericText())
        .animation(.easeInOut(duration: 0.3), value: maxChain)
        .animation(.easeInOut(duration: 0.3), value: syncedCount)
    }
}
