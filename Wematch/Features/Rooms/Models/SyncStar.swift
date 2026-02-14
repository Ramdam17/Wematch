import Foundation

/// A decorative star spawned when a sync pair forms.
/// Drifts randomly and fades out after 3 minutes.
struct SyncStar: Identifiable {
    let id = UUID()
    /// Normalized position (0...1) within the plot area.
    var position: CGPoint
    /// Drift velocity per tick (normalized units).
    var driftVelocity: CGPoint
    /// When the star was created.
    let birthDate = Date()
    /// Current opacity (1.0 → 0.0 over last 30s of lifetime).
    var opacity: Double = 1.0
}
