import Foundation

final class LocalFeatureFlagProvider: FeatureFlagProvider {
    func isEnabled(_ feature: Feature) -> Bool {
        true
    }
}
