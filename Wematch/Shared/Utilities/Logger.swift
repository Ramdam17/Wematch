import OSLog

/// `nonisolated`: logging must work from wherever the code runs. Under the project's
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` these would otherwise be main-actor
/// properties, which is absurd for a `Logger` — and would push the code paths that most
/// need a log (delegate queues, detached reads) into not having one (plan 1.10).
nonisolated enum Log {
    static let general = Logger(subsystem: "com.remyramadour.Wematch", category: "general")
    static let auth = Logger(subsystem: "com.remyramadour.Wematch", category: "authentication")
    static let cloudKit = Logger(subsystem: "com.remyramadour.Wematch", category: "cloudkit")
    static let firebase = Logger(subsystem: "com.remyramadour.Wematch", category: "firebase")
    static let healthKit = Logger(subsystem: "com.remyramadour.Wematch", category: "healthkit")
    static let watchConnectivity = Logger(subsystem: "com.remyramadour.Wematch", category: "watchconnectivity")
    static let sync = Logger(subsystem: "com.remyramadour.Wematch", category: "sync")
    static let friends = Logger(subsystem: "com.remyramadour.Wematch", category: "friends")
    static let groups = Logger(subsystem: "com.remyramadour.Wematch", category: "groups")
    static let rooms = Logger(subsystem: "com.remyramadour.Wematch", category: "rooms")
    static let inbox = Logger(subsystem: "com.remyramadour.Wematch", category: "inbox")
    static let featureFlags = Logger(subsystem: "com.remyramadour.Wematch", category: "featureflags")
    static let settings = Logger(subsystem: "com.remyramadour.Wematch", category: "settings")
}
