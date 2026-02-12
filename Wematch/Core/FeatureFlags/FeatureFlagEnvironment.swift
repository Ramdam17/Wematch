import SwiftUI

private struct FeatureFlagProviderKey: EnvironmentKey {
    static let defaultValue: any FeatureFlagProvider = LocalFeatureFlagProvider()
}

extension EnvironmentValues {
    var featureFlagProvider: any FeatureFlagProvider {
        get { self[FeatureFlagProviderKey.self] }
        set { self[FeatureFlagProviderKey.self] = newValue }
    }
}
