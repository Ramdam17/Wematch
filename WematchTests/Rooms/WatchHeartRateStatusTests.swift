import XCTest
import WematchCore
@testable import Wematch

/// A denied heart-rate read is invisible through HealthKit: `requestAuthorization`
/// returns normally and queries yield nothing, by design ("From the app's point of
/// view, no data of that type exists" — Apple, *Protecting User Privacy*). Before
/// this, the Watch started a workout, received nothing forever, and the phone
/// showed a participant whose heart never moved — indistinguishable from a working
/// room. These tests pin the reporting that replaces that silence.
@MainActor
final class WatchHeartRateStatusTests: XCTestCase {

    // MARK: - The status contract

    func testOnlySilenceAndAStoppedStreamSpeakUp() {
        XCTAssertTrue(WatchHeartRateStatus.silent.needsAttention)
        XCTAssertTrue(WatchHeartRateStatus.stopped.needsAttention)

        for healthy in [WatchHeartRateStatus.idle, .waitingForFirstSample, .streaming] {
            XCTAssertFalse(healthy.needsAttention, "\(healthy.rawValue) must not alarm anyone")
            XCTAssertNil(healthy.watchExplanation, "\(healthy.rawValue) has nothing to explain")
            XCTAssertNil(healthy.phoneSummary, "\(healthy.rawValue) has nothing to report")
        }
    }

    func testEveryStatusThatNeedsAttentionSaysWhatToDo() {
        for status in WatchHeartRateStatus.allCases where status.needsAttention {
            let explanation = status.watchExplanation
            XCTAssertNotNil(explanation, "\(status.rawValue) alarms without explaining")
            XCTAssertFalse(explanation?.isEmpty ?? true)
        }
    }

    // MARK: - One fact, two devices
    //
    // The Watch is where the user can act (Settings → Privacy → Health), so it gets the
    // instruction. The phone can only name the fault, and its banner sits on top of the
    // plot — so it gets one short sentence instead of three lines of advice.

    func testThePhoneAndTheWatchDoNotSayTheSameThing() {
        for status in WatchHeartRateStatus.allCases where status.needsAttention {
            XCTAssertNotEqual(status.phoneSummary, status.watchExplanation,
                              "\(status.rawValue) repeats an instruction the phone cannot act on")
        }
    }

    func testThePhoneSummaryIsShortEnoughToSitOverThePlot() {
        for status in WatchHeartRateStatus.allCases where status.needsAttention {
            let summary = status.phoneSummary ?? ""
            XCTAssertFalse(summary.isEmpty, "\(status.rawValue) alarms without saying anything")
            // Two lines at default type in a room-width pill; the three-line version is
            // what this replaces. Not a measurement — a ceiling, checked in the canvas.
            XCTAssertLessThanOrEqual(summary.count, 48, "'\(summary)' will wrap onto the plot")
            XCTAssertLessThan(summary.count, status.watchExplanation?.count ?? 0,
                              "the phone's wording must be the shorter of the two")
        }
    }

    /// The status crosses WCSession as its raw value. A rename that breaks the
    /// wire format would silently stop the phone from hearing anything.
    func testTheStatusSurvivesTheWireFormat() {
        for status in WatchHeartRateStatus.allCases {
            XCTAssertEqual(WatchHeartRateStatus(rawValue: status.rawValue), status)
        }
    }

    // MARK: - The phone actually hears it

    func testTheRoomHearsTheWatchGoSilent() async {
        let watchService = ScriptedWatchService()
        let viewModel = await makeViewModel(watchService: watchService)
        await viewModel.enterRoom()

        XCTAssertEqual(viewModel.watchHeartRateStatus, .idle, "nothing reported yet")

        watchService.deliver(.heartRateStatus(.silent))

        let heard = await waitUntil { viewModel.watchHeartRateStatus == .silent }
        XCTAssertTrue(heard, "the phone must hear the Watch report a dead heart-rate feed")
    }

    /// This used to hand the ViewModel `["type": "heartRateStatus", "status": "not_a_status"]`
    /// and check it stayed `.idle`. Since plan 1.10 that dictionary cannot be built: the
    /// seam carries a closed `WatchMessage`, so a malformed payload is rejected one layer
    /// down, at the wire. The rejection is tested there — `WatchMessageTests` — and what
    /// is left to pin here is that nothing arrives without a status attached.
    func testNothingButAStatusMessageMovesTheStatus() async {
        let watchService = ScriptedWatchService()
        let viewModel = await makeViewModel(watchService: watchService)
        await viewModel.enterRoom()

        watchService.deliver(.appLaunched)
        watchService.deliver(.exitRoom)

        // Give the consumer a chance to act on them before asserting it did not.
        _ = await waitUntil(timeout: 0.3) { viewModel.watchHeartRateStatus != .idle }
        XCTAssertEqual(viewModel.watchHeartRateStatus, .idle, "an unrelated message must not become state")
    }

    // MARK: - The heart rate itself

    /// The behaviour plan 1.10 made testable at all.
    ///
    /// Before it, a heart rate reached the phone's stream through a closure installed on
    /// `PhoneSessionManager.shared` and pointed at the concrete service the ViewModel
    /// obtained by downcasting its own injected protocol. Nothing about that path could be
    /// exercised without a Watch in the room — which is to say it has never been exercised,
    /// on the one path the field session is about to run for the first time.
    func testAHeartRateFromTheWatchReachesTheHeartRateSource() async {
        let watchService = ScriptedWatchService()
        let healthKit = MockHealthKitService()
        let viewModel = await makeViewModel(watchService: watchService, healthKitService: healthKit)
        await viewModel.enterRoom()

        watchService.deliver(.heartRate(bpm: 61, at: Date()))
        watchService.deliver(.heartRate(bpm: 64, at: Date()))

        let arrived = await waitUntil { healthKit.relayedHeartRates.count == 2 }
        XCTAssertTrue(arrived, "the Watch's heart rate never reached the phone's source")
        XCTAssertEqual(healthKit.relayedHeartRates, [61, 64], "samples must arrive in order")
    }

    func testLeavingTheRoomStopsRelayingHeartRate() async {
        let watchService = ScriptedWatchService()
        let healthKit = MockHealthKitService()
        let viewModel = await makeViewModel(watchService: watchService, healthKitService: healthKit)
        await viewModel.enterRoom()

        watchService.deliver(.heartRate(bpm: 61, at: Date()))
        _ = await waitUntil { healthKit.relayedHeartRates == [61] }

        await viewModel.exitRoom()
        watchService.deliver(.heartRate(bpm: 200, at: Date()))

        _ = await waitUntil(timeout: 0.3) { healthKit.relayedHeartRates.count > 1 }
        XCTAssertEqual(healthKit.relayedHeartRates, [61], "a room we left must not still be reading hearts")
    }

    func testLeavingTheRoomForgetsTheStatus() async {
        let watchService = ScriptedWatchService()
        let viewModel = await makeViewModel(watchService: watchService)
        await viewModel.enterRoom()

        watchService.deliver(.heartRateStatus(.silent))
        let heard = await waitUntil { viewModel.watchHeartRateStatus == .silent }
        XCTAssertTrue(heard, "nothing to forget if nothing was heard")

        await viewModel.exitRoom()
        XCTAssertEqual(viewModel.watchHeartRateStatus, .idle, "a stale alarm outlives its room")
    }

    // MARK: - Helpers

    private func makeViewModel(
        watchService: any WatchConnectivityServiceProtocol,
        healthKitService: MockHealthKitService = MockHealthKitService()
    ) async -> RoomViewModel {
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

        return RoomViewModel(
            roomID: "room1",
            roomName: "Test room",
            roomRepository: MockRoomRepository(),
            tempRoomRepository: SpyTemporaryRoomRepository(),
            healthKitService: healthKitService,
            watchService: watchService,
            dashboardStore: InMemoryDashboardRecordStore(),
            authManager: auth
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return condition()
    }
}

/// A Watch connectivity service whose message stream the test drives by hand.
/// `@unchecked Sendable` justification: test-only, every access happens from the
/// main actor inside a single test method; the continuation is created once in
/// `init` and never reassigned.
final class ScriptedWatchService: WatchConnectivityServiceProtocol, @unchecked Sendable {
    var isReachable = true

    private let stream: AsyncStream<WatchMessage>
    private let continuation: AsyncStream<WatchMessage>.Continuation

    init() {
        (stream, continuation) = AsyncStream<WatchMessage>.makeStream()
    }

    func activate() {}
    func send(_ message: WatchMessage) async throws {}
    func sendWithoutAcknowledgement(_ message: WatchMessage) {}

    func messages() -> AsyncStream<WatchMessage> { stream }

    func deliver(_ message: WatchMessage) {
        continuation.yield(message)
    }
}
