import WatchConnectivity
import OSLog

final class PhoneSessionManager: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = PhoneSessionManager()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else {
            Log.watchConnectivity.warning("WCSession not supported on this device")
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
        Log.watchConnectivity.info("WCSession activation requested (iPhone side)")
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            Log.watchConnectivity.error("WCSession activation failed: \(error.localizedDescription)")
        } else {
            Log.watchConnectivity.info("WCSession activated: \(String(describing: activationState))")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        Log.watchConnectivity.info("WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        Log.watchConnectivity.info("WCSession deactivated, reactivating")
        WCSession.default.activate()
    }
}
