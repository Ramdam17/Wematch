import XCTest
import FirebaseFirestore
@testable import Wematch

/// The retryable-vs-fatal taxonomy of plan 1.8 (audit D4), rewritten for Firestore.
final class BackendErrorTests: XCTestCase {

    private func firestoreError(_ code: FirestoreErrorCode.Code) -> NSError {
        NSError(domain: FirestoreErrorDomain, code: code.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "raw SDK text"])
    }

    func testTransientCodesAreTransient() {
        for code in [FirestoreErrorCode.Code.unavailable, .deadlineExceeded, .aborted, .resourceExhausted] {
            XCTAssertEqual(BackendError.classify(firestoreError(code)) as? BackendError, .transient, "\(code)")
        }
    }

    func testRulesRefusalIsDeniedNotANetworkHiccup() {
        XCTAssertEqual(BackendError.classify(firestoreError(.permissionDenied)) as? BackendError, .denied)
        XCTAssertEqual(BackendError.classify(firestoreError(.unauthenticated)) as? BackendError, .denied)
    }

    func testMissingDocumentIsNotFound() {
        XCTAssertEqual(BackendError.classify(firestoreError(.notFound)) as? BackendError, .notFound)
    }

    func testUnknownFirestoreCodeKeepsTheDescription() {
        XCTAssertEqual(BackendError.classify(firestoreError(.dataLoss)) as? BackendError, .unknown("raw SDK text"))
    }

    func testClientCancellationPassesThrough() {
        let error = firestoreError(.cancelled)
        XCTAssertNil(BackendError.classify(error) as? BackendError, "not a server verdict, not an alert")
    }

    func testOfflineURLErrorsAreOffline() {
        let error = URLError(.notConnectedToInternet)
        XCTAssertEqual(BackendError.classify(error) as? BackendError, .offline)
        XCTAssertEqual(BackendError.classify(URLError(.timedOut)) as? BackendError, .transient)
    }

    func testDomainErrorsPassThroughUntouched() {
        XCTAssertEqual(BackendError.classify(GroupError.groupFull) as? GroupError, .groupFull)
        XCTAssertEqual(BackendError.classify(FriendError.selfRequest) as? FriendError, .selfRequest)
        XCTAssertEqual(BackendError.classify(BackendError.denied) as? BackendError, .denied)
    }

    func testEveryCaseHasUserFacingText() {
        let cases: [BackendError] = [.offline, .transient, .denied, .notFound, .unknown("x")]
        for error in cases {
            XCTAssertFalse(error.localizedDescription.isEmpty, "\(error)")
            XCTAssertNotEqual(error.localizedDescription, "raw SDK text")
        }
    }
}
