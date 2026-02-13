import WatchConnectivity
import OSLog

final class PhoneSessionManager: NSObject, WCSessionDelegate, WatchConnectivityServiceProtocol, @unchecked Sendable {
    static let shared = PhoneSessionManager()

    // MARK: - State

    private(set) var isReachable = false
    private var messageContinuation: AsyncStream<[String: Any]>.Continuation?
    private var _receivedMessages: AsyncStream<[String: Any]>?

    /// Set by RoomViewModel to receive HR values from Watch.
    var heartRateHandler: ((Double) -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - WatchConnectivityServiceProtocol

    func activate() {
        guard WCSession.isSupported() else {
            Log.watchConnectivity.warning("WCSession not supported on this device")
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
        Log.watchConnectivity.info("WCSession activation requested (iPhone side)")
    }

    var receivedMessages: AsyncStream<[String: Any]> {
        if let existing = _receivedMessages { return existing }

        let stream = AsyncStream<[String: Any]> { continuation in
            self.messageContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                // Stream terminated
            }
        }
        _receivedMessages = stream
        return stream
    }

    func send(message: [String: Any]) async throws {
        guard WCSession.default.isReachable else {
            Log.watchConnectivity.warning("Watch not reachable — message not sent")
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            WCSession.default.sendMessage(message, replyHandler: { _ in
                continuation.resume()
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
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
            isReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        Log.watchConnectivity.info("WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        Log.watchConnectivity.info("WCSession deactivated, reactivating")
        WCSession.default.activate()
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
        Log.watchConnectivity.debug("Received message: \(type)")

        // Forward HR values directly to the handler
        if type == "heartRate", let hr = message["hr"] as? Double {
            heartRateHandler?(hr)
        }

        messageContinuation?.yield(message)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        isReachable = session.isReachable
        Log.watchConnectivity.info("Watch reachability changed: \(session.isReachable)")
    }
}
