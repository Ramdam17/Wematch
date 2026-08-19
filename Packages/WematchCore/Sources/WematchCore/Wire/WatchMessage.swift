import Foundation

/// Everything that crosses the phone↔Watch link, as one closed type (plan 1.10, H2).
///
/// It replaces seven ad-hoc `[String: Any]` shapes built and parsed at eleven call sites.
/// The dictionaries were not a transport detail: every reader was a chain of
/// `as? Double ?? 0` that turned a renamed key, a missing field or a whole unrecognised
/// message into a plausible-looking zero. A closed enum makes the set of things that can
/// arrive finite, and makes a payload that does not fit a thrown error rather than a
/// heart rate of 0 BPM on someone's plot.
///
/// One declaration, read by both devices. It was written duplicated, because
/// `WematchShared` was an iOS-only framework that could not carry it; plan 1.11 made the
/// package real and this is the copy that survived.
public enum WatchMessage: Codable, Sendable, Equatable {

    /// The phone came to the foreground. Wakes the Watch app; carries nothing.
    case appLaunched

    /// Start a workout session and begin streaming heart rate.
    case enterRoom(roomID: String)

    /// Stop the workout session.
    case exitRoom

    /// One heart-rate sample, Watch → phone.
    case heartRate(bpm: Double, at: Date)

    /// What the Watch's own feed is doing, Watch → phone. Sent on transitions only.
    case heartRateStatus(WatchHeartRateStatus)

    /// A resolved frame of the plot, phone → Watch, at ~1 Hz.
    case roomUpdate(RoomUpdate)

    /// A resolved dashboard, phone → Watch. Outlives any room.
    case dashboardUpdate(WatchDashboardSnapshot)

    // MARK: - Payloads

    /// The plot, already computed. The Watch is a passive display: it receives positions
    /// and counts, never the participants' identities or the graph they came from.
    public struct RoomUpdate: Codable, Sendable, Equatable {

        /// A heart on the plot. The palette *slot* travels, never a colour — each side
        /// resolves the hue for its own appearance (see `HeartPaletteSlot`).
        public struct Participant: Codable, Sendable, Equatable {
            public let id: String
            public let currentHR: Double
            public let previousHR: Double
            public let colorSlot: Int

            public init(id: String, currentHR: Double, previousHR: Double, colorSlot: Int) {
                self.id = id
                self.currentHR = currentHR
                self.previousHR = previousHR
                self.colorSlot = colorSlot
            }
        }

        public let participants: [Participant]
        public let currentUserID: String
        public let maxChain: Int
        public let syncedCount: Int
        public let newSyncFormations: Bool

        public init(
            participants: [Participant],
            currentUserID: String,
            maxChain: Int,
            syncedCount: Int,
            newSyncFormations: Bool
        ) {
            self.participants = participants
            self.currentUserID = currentUserID
            self.maxChain = maxChain
            self.syncedCount = syncedCount
            self.newSyncFormations = newSyncFormations
        }
    }

    /// A name safe to log. `String(describing:)` on this enum would put a heart rate in
    /// cleartext the day someone logs the wrong case — health data never goes to the
    /// console (audit B5), so the payloads simply have no textual form.
    public var logLabel: String {
        switch self {
        case .appLaunched: "appLaunched"
        case .enterRoom: "enterRoom"
        case .exitRoom: "exitRoom"
        case .heartRate: "heartRate"
        case .heartRateStatus(let status): "heartRateStatus(\(status.rawValue))"
        case .roomUpdate: "roomUpdate"
        case .dashboardUpdate: "dashboardUpdate"
        }
    }

    // MARK: - Wire format

    /// `WCSession` carries property-list types, not `Codable`, so the encoded message
    /// travels as `Data` under one key instead of being spread over a dictionary whose
    /// shape only the two call sites knew.
    private static let payloadKey = "wematch.payload"
    private static let versionKey = "wematch.version"

    /// Bumped when a case's payload changes shape. Nothing has ever been distributed —
    /// not even to TestFlight — so version 1 is the first and only format in existence,
    /// and no build predating it can be running anywhere.
    public static let wireVersion = 1

    public func encoded() throws -> [String: Any] {
        [
            Self.versionKey: Self.wireVersion,
            Self.payloadKey: try JSONEncoder().encode(self)
        ]
    }

    public static func decoded(from dictionary: [String: Any]) throws -> WatchMessage {
        guard let payload = dictionary[payloadKey] as? Data else {
            throw WatchMessageError.notAWematchMessage
        }
        guard let version = dictionary[versionKey] as? Int else {
            throw WatchMessageError.notAWematchMessage
        }
        guard version == wireVersion else {
            throw WatchMessageError.unsupportedVersion(version)
        }
        do {
            return try JSONDecoder().decode(WatchMessage.self, from: payload)
        } catch {
            throw WatchMessageError.malformed(String(describing: error))
        }
    }
}

/// Why a message could not be read. Named rather than collapsed into `nil` so the two
/// unrecoverable cases (a peer speaking a newer format, a payload that does not decode)
/// are distinguishable in a log — the field session is the first time either can happen.
public enum WatchMessageError: LocalizedError, Equatable {

    /// The dictionary did not come from Wematch's own encoder.
    case notAWematchMessage

    /// The peer runs a build whose wire format this one does not know.
    case unsupportedVersion(Int)

    /// Right envelope, unreadable contents.
    case malformed(String)

    public var errorDescription: String? {
        switch self {
        case .notAWematchMessage:
            "Received a message that did not come from Wematch."
        case .unsupportedVersion(let version):
            "Received a Wematch message in format \(version); this build reads format \(WatchMessage.wireVersion)."
        case .malformed(let reason):
            "Received a Wematch message that could not be read: \(reason)"
        }
    }
}
