import WatchConnectivity
import os

final class WatchSessionManager: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSessionManager()

    private let logger = Logger(
        subsystem: "com.remyramadour.Wematch.watchkitapp",
        category: "watchconnectivity"
    )

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else {
            logger.warning("WCSession not supported")
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
        logger.info("WCSession activation requested (Watch side)")
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            logger.error("WCSession activation failed: \(error.localizedDescription)")
        } else {
            logger.info("WCSession activated: \(String(describing: activationState))")
        }
    }
}
