import WatchKit

enum WatchHapticService {
    static func triggerSyncFormation() {
        WKInterfaceDevice.current().play(.notification)
    }
}
