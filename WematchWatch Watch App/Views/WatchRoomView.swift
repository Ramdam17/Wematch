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
