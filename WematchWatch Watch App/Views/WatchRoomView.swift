import SwiftUI

struct WatchRoomView: View {
    let viewModel: WatchRoomViewModel
    let onStop: () -> Void

    var body: some View {
        ZStack {
            // 2D Heart rate plot
            WatchHeartPlotView(
                participants: viewModel.participants,
                currentUserID: viewModel.currentUserID
            )

            // Says out loud when no heart rate is arriving. Without it the plot is
            // simply empty, which looks identical to a room nobody has joined yet.
            if let explanation = viewModel.heartRateStatus.explanation {
                VStack {
                    Text(explanation)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(.red.opacity(0.75), in: RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 6)

                    Spacer()
                }
                .padding(.top, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Heart rate unavailable. \(explanation)")
            }

            // Stats bar at bottom
            VStack {
                Spacer()

                HStack {
                    WatchStatsOverlayView(
                        heartRate: viewModel.ownHeartRate,
                        maxChain: viewModel.maxChain,
                        syncedCount: viewModel.syncedCount,
                        participantCount: viewModel.participants.count
                    )

                    Button(action: onStop) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(.bottom, 2)
        }
        .ignoresSafeArea(edges: .top)
    }
}
