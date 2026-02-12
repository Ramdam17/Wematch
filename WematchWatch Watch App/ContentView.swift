import SwiftUI

struct WatchPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 40))
                .foregroundStyle(.pink.gradient)
            Text("Wematch")
                .font(.headline)
            Text("Waiting for room...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    WatchPlaceholderView()
}
