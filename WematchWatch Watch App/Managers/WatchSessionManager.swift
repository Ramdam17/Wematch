import Synchronization
import WatchConnectivity
import os
import WematchCore

/// The Watch's end of the WatchConnectivity link.
///
/// **Why a lock and not an actor** — same reasoning as `PhoneSessionManager`, which this
/// mirrors: `WCSessionDelegate` callbacks arrive on WatchConnectivity's serial queue and
/// must stay synchronous and ordered (plan 1.10, C3). No `@unchecked`: every stored
/// property is a `let` or lives inside `state`.
///
/// The two stored handler closures are gone. They were `var`s written from the main actor
/// and read from the delegate queue — the actual data race under this type — and each one
/// re-dispatched through `DispatchQueue.main.async`, which is a second ordering hazard on
/// a stream where order is the signal. Both readers now take their own `messages()`
/// stream.
/// `nonisolated` on the declaration, not merely `Sendable`: conforming to `Sendable` is
/// not enough to stop the project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` from
/// isolating the members. Without it the `WCSessionDelegate` callbacks are main-actor
/// isolated while WatchConnectivity calls them on its own `NSOperationQueue` — which in
/// Swift 6 traps in `_checkExpectedExecutor` at the first activation, and in Swift 5
/// simply did the wrong thing quietly. It crashed the app on launch the moment the
/// language mode was raised; that is the bug this step exists to remove (plan 1.10, C3).
nonisolated final class WatchSessionManager: NSObject, WCSessionDelegate, Sendable {
    static let shared = WatchSessionManager()

    private let logger = Logger(
        subsystem: "com.remyramadour.Wematch.watchkitapp",
        category: "watchconnectivity"
    )

    // MARK: - State

    private struct State {
        var isReachable = false
        var consumers: [UUID: AsyncStream<WatchMessage>.Continuation] = [:]
    }

    private let state = Mutex(State())

    var isReachable: Bool { state.withLock(\.isReachable) }

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

    // MARK: - Sending to iPhone

    /// Best effort. The next sample is a second away, so a failed send is worth a log and
    /// nothing else — but it is never worth pretending it succeeded.
    func send(_ message: WatchMessage) {
        guard WCSession.default.isReachable else {
            logger.debug("iPhone not reachable — message not sent")
            return
        }

        guard let payload = try? message.encoded() else {
            logger.error("Could not encode a message for the iPhone")
            return
        }

        WCSession.default.sendMessage(payload, replyHandler: nil) { [logger] error in
            logger.error("Failed to send to iPhone: \(error.localizedDescription)")
        }
    }

    // MARK: - Receiving from iPhone

    /// A fresh stream per caller. Two readers exist on this side — the room and the
    /// dashboard, which outlives it — and one `AsyncStream` cannot serve both.
    func messages() -> AsyncStream<WatchMessage> {
        let id = UUID()
        return AsyncStream { continuation in
            state.withLock { $0.consumers[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.state.withLock { _ = $0.consumers.removeValue(forKey: id) }
            }
        }
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
            state.withLock { $0.isReachable = session.isReachable }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingMessage(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleIncomingMessage(message)
        replyHandler([:])
    }

    private func handleIncomingMessage(_ dictionary: [String: Any]) {
        let message: WatchMessage
        do {
            message = try WatchMessage.decoded(from: dictionary)
        } catch {
            logger.error("Unreadable message from iPhone: \(error.localizedDescription)")
            return
        }

        let consumers = state.withLock { Array($0.consumers.values) }
        for consumer in consumers {
            consumer.yield(message)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        state.withLock { $0.isReachable = session.isReachable }
        logger.info("iPhone reachability changed: \(session.isReachable)")
    }
}
