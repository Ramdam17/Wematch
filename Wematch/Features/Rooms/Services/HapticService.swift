import Foundation
#if os(iOS)
import UIKit
#elseif os(watchOS)
import WatchKit
#endif

/// Centralized haptic feedback for sync events.
enum HapticService {

    /// Trigger a single haptic pulse when a new sync pair forms.
    static func triggerSyncFormation() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #elseif os(watchOS)
        WKInterfaceDevice.current().play(.notification)
        #endif
    }
}
