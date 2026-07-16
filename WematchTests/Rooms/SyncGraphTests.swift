import XCTest
@testable import Wematch

/// Tests for the scientific core: sync-edge detection, clustering (Bron-Kerbosch
/// cliques, BFS components) and chain length (graph diameter).
///
/// Fixtures use known geometries in (currentHR, previousHR) space so every
/// expected result is derivable by hand.
final class SyncGraphTests: XCTestCase {

    // MARK: - Helpers

    private func participant(_ id: String, hr: Double, prev: Double) -> RoomParticipant {
        RoomParticipant(id: id, username: id, currentHR: hr, previousHR: prev, color: "FF6B9D")
    }

    // MARK: - Distance & Edges

    func testDistanceIsEuclideanIn2DHRSpace() {
        // 3-4-5 triangle: ΔcurrentHR = 3, ΔpreviousHR = 4 → distance 5
        let a = participant("a", hr: 60, prev: 60)
        let b = participant("b", hr: 63, prev: 64)
        let graph = SyncGraph(participants: [a, b])
        XCTAssertEqual(graph.distance(a, b), 5.0, accuracy: 1e-9)
    }

    func testEdgeAtExactThresholdIsInclusive() {
        // Distance exactly 5.0 with default threshold 5.0.
        // NOTE: spec (CAHIER_DES_CHARGES) says "< 5 BPM"; implementation uses <=.
        // This test pins the implemented behavior; flag before changing either.
        let a = participant("a", hr: 60, prev: 60)
        let b = participant("b", hr: 63, prev: 64)
        let graph = SyncGraph(participants: [a, b])
        XCTAssertTrue(graph.isEdge(a, b))
    }

    func testNoEdgeJustAboveThreshold() {
        let a = participant("a", hr: 60, prev: 60)
        let b = participant("b", hr: 63, prev: 64.01)
        let graph = SyncGraph(participants: [a, b])
        XCTAssertFalse(graph.isEdge(a, b))
    }

    func testIdenticalPositionsAreSynced() {
        let a = participant("a", hr: 72, prev: 70)
        let b = participant("b", hr: 72, prev: 70)
        let graph = SyncGraph(participants: [a, b])
        XCTAssertTrue(graph.isEdge(a, b))
    }

    func testCustomThreshold() {
        let a = participant("a", hr: 60, prev: 60)
        let b = participant("b", hr: 70, prev: 60) // distance 10
        XCTAssertFalse(SyncGraph(participants: [a, b], syncThreshold: 5).isEdge(a, b))
        XCTAssertTrue(SyncGraph(participants: [a, b], syncThreshold: 10).isEdge(a, b))
    }

    // MARK: - Adjacency

    func testAdjacencyListSymmetricAndComplete() {
        // Path: a—b—c (a and c too far apart from each other)
        let a = participant("a", hr: 60, prev: 60)
        let b = participant("b", hr: 64, prev: 60)
        let c = participant("c", hr: 68, prev: 60)
        let adj = SyncGraph(participants: [a, b, c]).adjacencyList

        XCTAssertEqual(adj["a"], ["b"])
        XCTAssertEqual(adj["b"], ["a", "c"])
        XCTAssertEqual(adj["c"], ["b"])
    }

    func testIsolatedParticipantHasEmptyAdjacencyEntry() {
        let a = participant("a", hr: 60, prev: 60)
        let loner = participant("loner", hr: 180, prev: 180)
        let adj = SyncGraph(participants: [a, loner]).adjacencyList
        XCTAssertEqual(adj["loner"], [])
    }

    // MARK: - Connected Components (soft clusters)

    func testConnectedComponentsTwoPairsAndAnIsolate() {
        let a = participant("a", hr: 60, prev: 60)
        let b = participant("b", hr: 62, prev: 60)   // pair with a
        let c = participant("c", hr: 120, prev: 120)
        let d = participant("d", hr: 122, prev: 120) // pair with c
        let e = participant("e", hr: 180, prev: 60)  // isolate

        let components = SyncGraph(participants: [a, b, c, d, e]).connectedComponents
        let sizes = components.map(\.count).sorted()
        XCTAssertEqual(sizes, [1, 2, 2])
    }

    func testSoftClustersExcludeSingletons() {
        let a = participant("a", hr: 60, prev: 60)
        let b = participant("b", hr: 62, prev: 60)
        let e = participant("e", hr: 180, prev: 60)

        let clusters = SyncGraph(participants: [a, b, e]).softClusters
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(Set(clusters[0].memberIDs), ["a", "b"])
        XCTAssertEqual(clusters[0].type, .soft)
    }

    // MARK: - Chain Length (diameter)

    func testChainLengthOfPathIsTwo() {
        // a—b—c path: farthest pair (a, c) is 2 hops apart
        let a = participant("a", hr: 60, prev: 60)
        let b = participant("b", hr: 64, prev: 60)
        let c = participant("c", hr: 68, prev: 60)
        let graph = SyncGraph(participants: [a, b, c])
        XCTAssertEqual(graph.chainLength(component: ["a", "b", "c"]), 2)
    }

    func testChainLengthOfTriangleIsOne() {
        // Equilateral-ish triangle, all pairwise distances ≤ 5
        let a = participant("a", hr: 60, prev: 60)
        let b = participant("b", hr: 63, prev: 60)
        let c = participant("c", hr: 60, prev: 63)
        let graph = SyncGraph(participants: [a, b, c])
        XCTAssertEqual(graph.chainLength(component: ["a", "b", "c"]), 1)
    }

    func testChainLengthOfPairIsOneAndSingletonIsZero() {
        let a = participant("a", hr: 60, prev: 60)
        let b = participant("b", hr: 62, prev: 60)
        let graph = SyncGraph(participants: [a, b])
        XCTAssertEqual(graph.chainLength(component: ["a", "b"]), 1)
        XCTAssertEqual(graph.chainLength(component: ["a"]), 0)
    }

    // MARK: - Cliques (hard clusters)

    func testTriangleIsSingleMaximalClique() {
        let a = participant("a", hr: 60, prev: 60)
        let b = participant("b", hr: 63, prev: 60)
        let c = participant("c", hr: 60, prev: 63)
        let cliques = SyncGraph(participants: [a, b, c]).maxCliques
        XCTAssertEqual(cliques.count, 1)
        XCTAssertEqual(Set(cliques[0]), ["a", "b", "c"])
    }

    func testPathYieldsTwoEdgeCliques() {
        // a—b—c path: maximal cliques are {a,b} and {b,c}, NOT {a,b,c}
        let a = participant("a", hr: 60, prev: 60)
        let b = participant("b", hr: 64, prev: 60)
        let c = participant("c", hr: 68, prev: 60)
        let cliques = SyncGraph(participants: [a, b, c]).maxCliques
        let sets = Set(cliques.map(Set.init))
        XCTAssertEqual(sets, [["a", "b"], ["b", "c"]])
    }

    func testIsolatedNodesProduceNoClique() {
        let a = participant("a", hr: 60, prev: 60)
        let b = participant("b", hr: 180, prev: 180)
        XCTAssertTrue(SyncGraph(participants: [a, b]).maxCliques.isEmpty)
    }

    func testHardClusterChainLengthIsCliqueSizeMinusOne() {
        let a = participant("a", hr: 60, prev: 60)
        let b = participant("b", hr: 63, prev: 60)
        let c = participant("c", hr: 60, prev: 63)
        let hard = SyncGraph(participants: [a, b, c]).hardClusters
        XCTAssertEqual(hard.count, 1)
        XCTAssertEqual(hard[0].chainLength, 2)
        XCTAssertEqual(hard[0].type, .hard)
    }

    // MARK: - Synced Pairs

    func testSyncedPairsAreCanonical() {
        XCTAssertEqual(SyncPair("b", "a"), SyncPair("a", "b"))
        XCTAssertEqual(SyncPair("b", "a").id1, "a")
    }

    func testSyncedPairsMatchEdges() {
        let a = participant("a", hr: 60, prev: 60)
        let b = participant("b", hr: 64, prev: 60)
        let c = participant("c", hr: 68, prev: 60)
        let pairs = SyncGraph(participants: [a, b, c]).syncedPairs
        XCTAssertEqual(pairs, [SyncPair("a", "b"), SyncPair("b", "c")])
    }

    // MARK: - Degenerate inputs

    func testEmptyGraphDoesNotCrash() {
        let graph = SyncGraph(participants: [])
        XCTAssertTrue(graph.connectedComponents.isEmpty)
        XCTAssertTrue(graph.maxCliques.isEmpty)
        XCTAssertTrue(graph.syncedPairs.isEmpty)
        XCTAssertTrue(graph.softClusters.isEmpty)
    }

    func testSingleParticipantGraph() {
        let graph = SyncGraph(participants: [participant("a", hr: 60, prev: 60)])
        XCTAssertEqual(graph.connectedComponents, [["a"]])
        XCTAssertTrue(graph.maxCliques.isEmpty)
        XCTAssertTrue(graph.softClusters.isEmpty)
    }
}
