import WatchConnectivity
import os

final class WatchSessionManager: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSessionManager()

    private let logger = Logger(
        subsystem: "com.remyramadour.Wematch.watchkitapp",
        category: "watchconnectivity"
    )

    // MARK: - State

    private(set) var isReachable = false

    // Command stream (enterRoom / exitRoom)
    private var commandContinuation: AsyncStream<[String: Any]>.Continuation?
    private var _receivedMessages: AsyncStream<[String: Any]>?

    /// Set by WatchRoomViewModel to receive room updates from iPhone.
    var roomUpdateHandler: ((WatchRoomUpdate) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - Activation

    func activate() {
        guard WCSession.isSupported() else {
            logger.warning("WCSession not supported")
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
        logger.info("WCSession activation requested (Watch side)")
    }

    // MARK: - Sending HR to iPhone

    func sendHeartRate(_ hr: Double, timestamp: Date = Date()) {
        guard WCSession.default.isReachable else {
            logger.debug("iPhone not reachable — HR not sent")
            return
        }

        let message: [String: Any] = [
            "type": "heartRate",
            "hr": hr,
            "timestamp": timestamp.timeIntervalSince1970
        ]

        WCSession.default.sendMessage(message, replyHandler: nil) { [weak self] error in
            self?.logger.error("Failed to send HR: \(error.localizedDescription)")
        }
    }

    // MARK: - Receiving Commands from iPhone

    var receivedMessages: AsyncStream<[String: Any]> {
        if let existing = _receivedMessages { return existing }

        let stream = AsyncStream<[String: Any]> { continuation in
            self.commandContinuation = continuation
            continuation.onTermination = { @Sendable _ in }
        }
        _receivedMessages = stream
        return stream
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
            isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleIncomingMessage(message)
        replyHandler(["status": "received"])
    }

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "roomUpdate":
            if let update = WatchRoomUpdate(from: message) {
                DispatchQueue.main.async { [weak self] in
                    self?.roomUpdateHandler?(update)
                }
            }
        default:
            logger.debug("Received command: \(type)")
            commandContinuation?.yield(message)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        isReachable = session.isReachable
        logger.info("iPhone reachability changed: \(session.isReachable)")
    }
}
