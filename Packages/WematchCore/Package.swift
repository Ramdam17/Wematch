// swift-tools-version: 6.2
import PackageDescription

/// The value types both apps need, in one place (plan 1.11, audit H1).
///
/// It replaces the `WematchShared` framework, which was created iOS-only and therefore
/// could never be what its name claimed: every model the Watch shares with the phone was
/// copied by hand instead, with a comment asking the reader to keep the copies in sync.
/// Two of them had already drifted.
///
/// Nothing in here imports either app, touches the network, or knows what a ViewModel is.
/// The rule for what belongs: a type the phone and the Watch must agree on exactly — the
/// wire format, the palette, the plot's coordinate system.
///
/// No `defaultIsolation` is set, so the package is `nonisolated` throughout. That is the
/// opposite of the apps' `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and deliberately so:
/// these are pure values, decoded on a WatchConnectivity delegate queue as often as they
/// are read in a `View`.
let package = Package(
    name: "WematchCore",
    platforms: [.iOS(.v26), .watchOS(.v26)],
    products: [
        .library(name: "WematchCore", targets: ["WematchCore"])
    ],
    // No test target here on purpose. `swift test` would build for macOS, which this
    // package does not support, so it could never be run from the command line — and a
    // test target nobody can run is worse than none. These types are covered by
    // `WematchTests`, which runs on the simulator against the real dependency graph.
    targets: [
        .target(name: "WematchCore")
    ]
)
