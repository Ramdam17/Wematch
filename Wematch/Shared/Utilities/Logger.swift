import OSLog

enum Log {
    static let general = Logger(subsystem: "com.remyramadour.Wematch", category: "general")
    static let auth = Logger(subsystem: "com.remyramadour.Wematch", category: "authentication")
    static let cloudKit = Logger(subsystem: "com.remyramadour.Wematch", category: "cloudkit")
    static let firebase = Logger(subsystem: "com.remyramadour.Wematch", category: "firebase")
    static let healthKit = Logger(subsystem: "com.remyramadour.Wematch", category: "healthkit")
    static let watchConnectivity = Logger(subsystem: "com.remyramadour.Wematch", category: "watchconnectivity")
    static let sync = Logger(subsystem: "com.remyramadour.Wematch", category: "sync")
    static let groups = Logger(subsystem: "com.remyramadour.Wematch", category: "groups")
    static let rooms = Logger(subsystem: "com.remyramadour.Wematch", category: "rooms")
    static let featureFlags = Logger(subsystem: "com.remyramadour.Wematch", category: "featureflags")
}
