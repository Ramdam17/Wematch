import Foundation

// MARK: - Cluster Types

enum ClusterType: Sendable {
    case soft
    case hard
}

struct SyncCluster: Identifiable, Sendable {
    let id: UUID
    let memberIDs: [String]
    let type: ClusterType
    let chainLength: Int

    init(memberIDs: [String], type: ClusterType, chainLength: Int) {
        self.id = UUID()
        self.memberIDs = memberIDs
        self.type = type
        self.chainLength = chainLength
    }
}

// MARK: - SyncGraph

struct SyncGraph: Sendable {

    let participants: [RoomParticipant]
    let syncThreshold: Double

    init(participants: [RoomParticipant], syncThreshold: Double = 5.0) {
        self.participants = participants
        self.syncThreshold = syncThreshold
    }

    // MARK: - Edge Detection

    /// Euclidean distance in 2D HR space (currentHR, previousHR).
    func distance(_ a: RoomParticipant, _ b: RoomParticipant) -> Double {
        let dx = a.currentHR - b.currentHR
        let dy = a.previousHR - b.previousHR
        return sqrt(dx * dx + dy * dy)
    }

    /// Two participants are synced if their 2D euclidean distance < threshold.
    func isEdge(_ a: RoomParticipant, _ b: RoomParticipant) -> Bool {
        distance(a, b) <= syncThreshold
    }

    // MARK: - Adjacency

    /// Adjacency list: userID → set of synced userIDs.
    var adjacencyList: [String: Set<String>] {
        var adj: [String: Set<String>] = [:]
        for p in participants {
            adj[p.id] = []
        }
        for i in participants.indices {
            for j in (i + 1)..<participants.count {
                let a = participants[i]
                let b = participants[j]
                if isEdge(a, b) {
                    adj[a.id, default: []].insert(b.id)
                    adj[b.id, default: []].insert(a.id)
                }
            }
        }
        return adj
    }

    // MARK: - Connected Components (Soft Clusters)

    /// BFS to find all connected components in the sync graph.
    var connectedComponents: [[String]] {
        let adj = adjacencyList
        var visited = Set<String>()
        var components: [[String]] = []

        for participant in participants {
            let node = participant.id
            guard !visited.contains(node) else { continue }

            var component: [String] = []
            var queue: [String] = [node]
            visited.insert(node)

            while !queue.isEmpty {
                let current = queue.removeFirst()
                component.append(current)
                for neighbor in adj[current, default: []] where !visited.contains(neighbor) {
                    visited.insert(neighbor)
                    queue.append(neighbor)
                }
            }

            components.append(component)
        }

        return components
    }

    // MARK: - Clique Detection (Hard Clusters)

    /// Bron-Kerbosch with pivot to find all maximal cliques.
    var maxCliques: [[String]] {
        let adj = adjacencyList
        let allNodes = Set(participants.map { $0.id })
        var cliques: [[String]] = []

        bronKerbosch(
            r: [],
            p: allNodes,
            x: [],
            adj: adj,
            cliques: &cliques
        )

        return cliques
    }

    private func bronKerbosch(
        r: Set<String>,
        p: Set<String>,
        x: Set<String>,
        adj: [String: Set<String>],
        cliques: inout [[String]]
    ) {
        if p.isEmpty && x.isEmpty {
            if r.count >= 2 {
                cliques.append(Array(r))
            }
            return
        }

        // Pick pivot: node in P ∪ X with most connections to P
        let union = p.union(x)
        let pivot = union.max { adj[$0, default: []].intersection(p).count < adj[$1, default: []].intersection(p).count }!

        let candidates = p.subtracting(adj[pivot, default: []])

        for node in candidates {
            let neighbors = adj[node, default: []]
            bronKerbosch(
                r: r.union([node]),
                p: p.intersection(neighbors),
                x: x.intersection(neighbors),
                adj: adj,
                cliques: &cliques
            )
        }
    }

    // MARK: - Chain Length (Diameter)

    /// Graph diameter of a component via BFS from each node.
    func chainLength(component: [String]) -> Int {
        guard component.count >= 2 else { return 0 }

        let adj = adjacencyList
        var maxDistance = 0

        for start in component {
            let farthest = bfsMaxDistance(from: start, adj: adj)
            maxDistance = max(maxDistance, farthest)
        }

        return maxDistance
    }

    private func bfsMaxDistance(from start: String, adj: [String: Set<String>]) -> Int {
        var visited = Set([start])
        var queue: [(String, Int)] = [(start, 0)]
        var maxDist = 0

        while !queue.isEmpty {
            let (current, dist) = queue.removeFirst()
            maxDist = max(maxDist, dist)
            for neighbor in adj[current, default: []] where !visited.contains(neighbor) {
                visited.insert(neighbor)
                queue.append((neighbor, dist + 1))
            }
        }

        return maxDist
    }

    // MARK: - Convenience

    /// Soft clusters: connected components with 2+ members.
    var softClusters: [SyncCluster] {
        connectedComponents
            .filter { $0.count >= 2 }
            .map { component in
                SyncCluster(
                    memberIDs: component,
                    type: .soft,
                    chainLength: chainLength(component: component)
                )
            }
    }

    /// Hard clusters: maximal cliques with 2+ members.
    var hardClusters: [SyncCluster] {
        maxCliques.map { clique in
            SyncCluster(
                memberIDs: clique,
                type: .hard,
                chainLength: clique.count - 1
            )
        }
    }
}
