import Synchronization
import WatchConnectivity
import OSLog
import WematchCore

/// The phone's end of the WatchConnectivity link.
///
/// **Why a lock and not an actor** (plan 1.10, C3). `WCSessionDelegate` callbacks arrive
/// on WatchConnectivity's own serial queue, and `isReachable` is read synchronously from
/// the main actor while they land. An actor would force every delegate method to be
/// `nonisolated` and hop in through an unordered `Task`, which is how a heart-rate stream
/// gets reordered, and would make `isReachable` `async` — a property the UI reads inside a
/// `body`. A mutex keeps the delegate callbacks synchronous and ordered, keeps the reads
/// synchronous, and needs no `@unchecked`: every stored property below is either a `let`
/// or lives inside `state`.
/// `nonisolated` on the declaration, not merely `Sendable`: conforming to `Sendable` is
/// not enough to stop the project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` from
/// isolating the members. Without it the `WCSessionDelegate` callbacks are main-actor
/// isolated while WatchConnectivity calls them on its own `NSOperationQueue` — which in
/// Swift 6 traps in `_checkExpectedExecutor` at the first activation, and in Swift 5
/// simply did the wrong thing quietly. It crashed the app on launch the moment the
/// language mode was raised; that is the bug this step exists to remove (plan 1.10, C3).
nonisolated final class PhoneSessionManager: NSObject, WCSessionDelegate, WatchConnectivityServiceProtocol, Sendable {

    /// The one instance, created and activated by `WematchApp` and injected from there.
    /// ViewModels never reach for it (`CLAUDE.md`); the app entry point is allowed to
    /// know a concrete type, that is what a composition root is.
    static let shared = PhoneSessionManager()

    // MARK: - State

    /// Everything mutable, behind one lock. Held only long enough to copy values out —
    /// never across a `yield` to a consumer or a call into WatchConnectivity.
    private struct State {
        var isReachable = false
        var consumers: [UUID: AsyncStream<WatchMessage>.Continuation] = [:]
    }

    private let state = Mutex(State())

    var isReachable: Bool { state.withLock(\.isReachable) }

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

    func messages() -> AsyncStream<WatchMessage> {
        let id = UUID()
        return AsyncStream { continuation in
            state.withLock { $0.consumers[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.state.withLock { _ = $0.consumers.removeValue(forKey: id) }
            }
        }
    }

    func send(_ message: WatchMessage) async throws {
        // Was: log and `return`, which reported success for a message that never left
        // the phone (plan 1.7, D1). A throwing function that returns normally on
        // failure is the silent failure the audit named.
        guard WCSession.default.isReachable else {
            Log.watchConnectivity.error("Watch not reachable — message not sent")
            throw WatchConnectivityError.watchUnreachable
        }

        let payload = try message.encoded()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            WCSession.default.sendMessage(payload, replyHandler: { _ in
                continuation.resume()
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
    }

    func sendWithoutAcknowledgement(_ message: WatchMessage) {
        guard WCSession.default.isReachable else { return }

        guard let payload = try? message.encoded() else {
            // Encoding a `WatchMessage` fails only on a programming error, so this is
            // worth a log rather than a throw the ~1 Hz caller could not act on.
            Log.watchConnectivity.error("Could not encode a message for the Watch")
            return
        }

        WCSession.default.sendMessage(payload, replyHandler: nil) { error in
            Log.watchConnectivity.debug("Fire-and-forget send failed: \(error.localizedDescription)")
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
            state.withLock { $0.isReachable = session.isReachable }
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
        replyHandler([:])
    }

    private func handleIncomingMessage(_ dictionary: [String: Any]) {
        let message: WatchMessage
        do {
            message = try WatchMessage.decoded(from: dictionary)
        } catch {
            // Was a `guard let ... else { return }` on an untyped dictionary, which is
            // how a message the phone could not read became indistinguishable from one
            // that never arrived.
            Log.watchConnectivity.error("Unreadable message from Watch: \(error.localizedDescription)")
            return
        }

        // Copy the consumers out before yielding: a consumer's continuation must never
        // be driven with the lock held.
        let consumers = state.withLock { Array($0.consumers.values) }
        for consumer in consumers {
            consumer.yield(message)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        state.withLock { $0.isReachable = session.isReachable }
        Log.watchConnectivity.info("Watch reachability changed: \(session.isReachable)")
    }
}
