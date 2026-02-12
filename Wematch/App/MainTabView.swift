import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .rooms
    @State private var inboxUnreadCount = 0

    enum AppTab: String {
        case rooms, groups, friends, inbox
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Rooms", systemImage: "heart.circle.fill", value: .rooms) {
                NavigationStack {
                    RoomsPlaceholderView()
                }
            }

            Tab("Groups", systemImage: "person.3.fill", value: .groups) {
                NavigationStack {
                    GroupListView()
                }
            }

            Tab("Friends", systemImage: "person.2.fill", value: .friends) {
                NavigationStack {
                    FriendListView()
                }
            }

            Tab("Inbox", systemImage: "envelope.fill", value: .inbox) {
                NavigationStack {
                    InboxListView(unreadCount: $inboxUnreadCount)
                }
            }
            .badge(inboxUnreadCount)
        }
    }
}

#Preview {
    MainTabView()
}
