import XCTest
@testable import Wematch

@MainActor
final class DashboardViewModelTests: XCTestCase {

    private let origin = Date(timeIntervalSince1970: 5_000_000)

    // MARK: - States

    func testAnEmptyStoreShowsTheEmptyStateRatherThanZeroes() async {
        let viewModel = makeViewModel(auth: await makeSignedInAuth(), store: InMemoryDashboardRecordStore())

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .empty, "'no history' and 'all zeroes' are different claims")
    }

    func testRecordsProduceMetricsAndAResolvedPartner() async throws {
        let auth = await makeSignedInAuth()
        let me = try XCTUnwrap(auth.currentUserID).firebaseSafe()
        let store = InMemoryDashboardRecordStore(seeded: seededRecords(me: me))
        let viewModel = makeViewModel(auth: auth, store: store)

        await viewModel.load()

        guard case .loaded(let metrics) = viewModel.state else {
            return XCTFail("expected loaded, got \(viewModel.state)")
        }
        XCTAssertEqual(metrics.totalStars, 9)
        XCTAssertEqual(metrics.connectedDuration, 300)
        XCTAssertEqual(viewModel.bestPartnerName, "brave_otter")
        XCTAssertEqual(viewModel.bestPartnerSlot, HeartPaletteSlot(userID: "a"))
    }

    /// The rule is that feature availability is decided in the ViewModel, not the view —
    /// so it must hold no matter which entry point reaches this screen.
    func testTheFlagIsHonouredHere() async throws {
        let auth = await makeSignedInAuth()
        let me = try XCTUnwrap(auth.currentUserID).firebaseSafe()
        let viewModel = makeViewModel(
            auth: auth,
            store: InMemoryDashboardRecordStore(seeded: seededRecords(me: me)),
            flags: StubFeatureFlagProvider(enabled: false)
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .unavailable)
    }

    func testAnUnreadableHistorySurfacesRatherThanLookingEmpty() async {
        let viewModel = makeViewModel(auth: await makeSignedInAuth(), store: ThrowingDashboardRecordStore())

        await viewModel.load()

        XCTAssertNotNil(viewModel.error, "a read failure must reach the user, not pass as 'nothing yet'")
    }

    // MARK: - Formatting

    func testDurationTextPicksTheCoarsestUsefulUnit() {
        XCTAssertEqual(DashboardViewModel.durationText(0), "0s")
        XCTAssertEqual(DashboardViewModel.durationText(38), "38s")
        XCTAssertEqual(DashboardViewModel.durationText(59.4), "59s")
        XCTAssertEqual(DashboardViewModel.durationText(59.6), "1m", "rounds to 60s, which is a minute")
        XCTAssertEqual(DashboardViewModel.durationText(60), "1m")
        XCTAssertEqual(DashboardViewModel.durationText(2_520), "42m")
        XCTAssertEqual(DashboardViewModel.durationText(13_320), "3h 42m")
        XCTAssertEqual(DashboardViewModel.durationText(7_200), "2h 0m")
    }

    func testTheSpokenFormIsNotReadLetterByLetter() {
        XCTAssertEqual(DashboardViewModel.durationSpoken(13_320), "3 hours 42 minutes")
        XCTAssertEqual(DashboardViewModel.durationSpoken(3_660), "1 hour 1 minute")
        XCTAssertEqual(DashboardViewModel.durationSpoken(38), "38 seconds")
    }

    /// The shared contract between the phone and the Watch.
    ///
    /// The Watch reimplements this formatting in its own target (it cannot import this
    /// one — `WematchShared` is iOS-only, the same reason `WatchHeartPalette` is
    /// duplicated), so no test can compare the two implementations directly. This table
    /// is what both are written against: if it changes, change
    /// `WatchDashboardSnapshot.connectedDurationText` in the Watch target by hand.
    func testTheDurationContractTheWatchIsAlsoWrittenAgainst() {
        let expected: [(TimeInterval, String, String)] = [
            (0, "0s", "0 seconds"),
            (45, "45s", "45 seconds"),
            (60, "1m", "1 minute"),
            (599, "9m", "9 minutes"),
            (3_600, "1h 0m", "1 hour"),
            (13_320, "3h 42m", "3 hours 42 minutes"),
            (86_400, "24h 0m", "24 hours")
        ]

        for (seconds, text, spoken) in expected {
            XCTAssertEqual(DashboardViewModel.durationText(seconds), text, "text for \(seconds)s")
            XCTAssertEqual(DashboardViewModel.durationSpoken(seconds), spoken, "spoken for \(seconds)s")
        }
    }

    // MARK: - Helpers

    /// Signed in, or `load()` short-circuits to `.empty` before it ever reads the store —
    /// correct behaviour, and it would silently pass the wrong tests.
    ///
    /// `MockSignInWithAppleCoordinator` is not optional: without it the real coordinator
    /// presents an `ASAuthorizationController`, which never returns in a test host and
    /// hangs the whole suite rather than failing it.
    private func makeSignedInAuth() async -> AuthenticationManager {
        let profileRepo = MockUserProfileRepository()
        profileRepo.profiles["firebase_uid_mock"] = UserProfile(
            id: "firebase_uid_mock", username: "cosmic_panda0042",
            displayName: nil, createdAt: Date(), usernameEdited: false
        )

        let auth = AuthenticationManager(
            repository: profileRepo,
            coordinator: MockSignInWithAppleCoordinator(),
            keychain: InMemoryKeychain(),
            firebaseAuth: MockFirebaseAuthService()
        )
        await auth.signInWithApple()
        return auth
    }

    private func makeViewModel(
        auth: AuthenticationManager,
        store: any DashboardRecordStoring,
        flags: any FeatureFlagProvider = StubFeatureFlagProvider(enabled: true)
    ) -> DashboardViewModel {
        DashboardViewModel(authManager: auth, store: store, featureFlags: flags)
    }

    /// Records must be keyed on the *signed-in* user. Seeding them with a literal "me"
    /// makes the real user a stranger and every other ID a partner, including "me" —
    /// which the tie-break then hides.
    private func seededRecords(me: String) -> DashboardRecords {
        DashboardRecords(
            sessions: [
                SessionLog(
                    id: "s1", roomID: "room", userID: me,
                    joinedAt: origin, leftAt: origin.addingTimeInterval(600), starsSpawned: 9
                )
            ],
            syncEvents: [
                SyncEvent(
                    id: "e1", roomID: "room", userIDs: [me, "a"],
                    startedAt: origin, endedAt: origin.addingTimeInterval(300)
                )
            ],
            displayNames: ["a": "brave_otter"]
        )
    }
}

// MARK: - Stubs

private struct StubFeatureFlagProvider: FeatureFlagProvider {
    let enabled: Bool
    func isEnabled(_ feature: Feature) -> Bool { enabled }
}

private struct ThrowingDashboardRecordStore: DashboardRecordStoring {
    struct Unreadable: Error {}
    func load() throws -> DashboardRecords { throw Unreadable() }
    func append(_ records: DashboardRecords) throws {}
    func deleteAll() throws {}
}
