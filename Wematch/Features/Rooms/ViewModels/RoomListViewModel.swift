import Foundation
import OSLog

@Observable
@MainActor
final class RoomListViewModel {

    // MARK: - State

    private(set) var groups: [Group] = []
    private(set) var temporaryRooms: [TemporaryRoom] = []
    private(set) var isLoading = false
    var error: Error?

    var isEmpty: Bool {
        groups.isEmpty && temporaryRooms.isEmpty
    }

    // MARK: - Dependencies

    private let groupRepository: any GroupRepository
    private let tempRoomRepository: any TemporaryRoomRepository
    private let authManager: AuthenticationManager

    // MARK: - Init

    init(groupRepository: (any GroupRepository)? = nil,
         tempRoomRepository: (any TemporaryRoomRepository)? = nil,
         authManager: AuthenticationManager) {
        self.groupRepository = groupRepository ?? CloudKitGroupRepository()
        self.tempRoomRepository = tempRoomRepository ?? FirebaseTemporaryRoomRepository()
        self.authManager = authManager
    }

    // MARK: - Computed

    var currentUserID: String? { authManager.currentUserID }

    // MARK: - Actions

    func fetchRooms() async {
        guard let userID = currentUserID else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            async let fetchedGroups = groupRepository.fetchMyGroups(userID: userID)
            async let fetchedTempRooms = tempRoomRepository.fetchActiveRooms(userID: userID)

            groups = try await fetchedGroups
            temporaryRooms = (try? await fetchedTempRooms) ?? []

            Log.rooms.debug("Fetched \(self.groups.count) groups + \(self.temporaryRooms.count) temp rooms")
        } catch {
            self.error = error
            Log.rooms.error("Failed to fetch rooms: \(error.localizedDescription)")
        }
    }
}
