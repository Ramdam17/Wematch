import Foundation
import FirebaseFirestore

/// What a backend failure means to the person holding the phone.
///
/// The Firebase SDKs throw `NSError`s whose `localizedDescription` is written for the
/// developer ("Missing or insufficient permissions."), and every ViewModel used to hand
/// that string straight to an alert. This is the retryable-vs-fatal taxonomy plan step
/// 1.8 asked for — written for Firestore rather than CloudKit, since decision 0001
/// replaced one with the other (audit D4).
///
/// Two families the user can act on differently:
/// - **transient** (`offline`, `transient`): the same action, tried again, can succeed —
///   the phone is offline, the server said "come back later", a transaction was aborted
///   under contention. Firestore queues writes and serves cached reads while offline, so
///   there is deliberately no automatic retry here: retrying on top of the SDK's own
///   backoff only multiplies traffic, and a user told to try again is a user who knows.
/// - **fatal** (`denied`, `notFound`, `unknown`): trying again changes nothing. `denied`
///   is the one that matters most — a security-rules refusal is a bug in the rules or in
///   the app, and it must never read like a network hiccup (audit D2).
///
/// Domain errors (`GroupError`, `FriendError`, `RoomError`, `UsernameError`) already
/// carry user-facing text; `classify` returns them untouched.
nonisolated enum BackendError: LocalizedError, Equatable {
    /// No connection at all (URL loading layer).
    case offline
    /// The server refused *for now*: unavailable, deadline exceeded, aborted, quota.
    case transient
    /// Security rules or missing authentication. Not the user's fault, not fixable by them.
    case denied
    /// The document the action needed no longer exists.
    case notFound
    /// A backend error this taxonomy does not know. The underlying description is kept
    /// so that the log, if not the alert, says what happened.
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .offline:
            "You're offline. Check your connection and try again."
        case .transient:
            "The server didn't answer in time. Please try again."
        case .denied:
            "Wematch isn't allowed to do that. If this keeps happening, sign out and back in."
        case .notFound:
            "That item no longer exists."
        case .unknown(let description):
            "Something went wrong: \(description)"
        }
    }

    /// Wraps a Firestore or URL-loading error in its user-facing meaning; anything else —
    /// domain errors, already-classified errors — passes through unchanged.
    ///
    /// Not tempted into a "kind" for the RTDB: its errors reach the room as
    /// `RoomConnectionState`, which is a richer surface than an alert (plan 1.7).
    static func classify(_ error: any Error) -> any Error {
        let nsError = error as NSError
        switch nsError.domain {
        case NSURLErrorDomain:
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
                 NSURLErrorDataNotAllowed, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                return BackendError.offline
            case NSURLErrorTimedOut:
                return BackendError.transient
            default:
                return BackendError.unknown(nsError.localizedDescription)
            }
        case FirestoreErrorDomain:
            switch FirestoreErrorCode.Code(rawValue: nsError.code) {
            case .unavailable, .deadlineExceeded, .aborted, .resourceExhausted:
                return BackendError.transient
            case .permissionDenied, .unauthenticated:
                return BackendError.denied
            case .notFound:
                return BackendError.notFound
            case .cancelled:
                // The client gave up (a task was cancelled) — not a server verdict, and
                // not something to alert the user about.
                return error
            default:
                return BackendError.unknown(nsError.localizedDescription)
            }
        default:
            // Swift errors bridge with their own domain (`Wematch.GroupError`): domain
            // errors, `BackendError` itself, anything not from the backend — untouched.
            return error
        }
    }
}
