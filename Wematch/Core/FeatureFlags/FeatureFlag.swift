import Foundation

enum Feature: String, CaseIterable, Sendable {
    case roomAccess
    case groupCreation
    case groupJoin
    case friendList
    case temporaryRooms
    case dashboardAccess
    case inboxAccess
    case customHeartSkins
    case customRoomBackgrounds
    case advancedAnalytics
}

protocol FeatureFlagProvider: Sendable {
    func isEnabled(_ feature: Feature) -> Bool
}
