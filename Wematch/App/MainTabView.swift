import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .rooms

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
                    FriendsPlaceholderView()
                }
            }

            Tab("Inbox", systemImage: "envelope.fill", value: .inbox) {
                NavigationStack {
                    InboxPlaceholderView()
                }
            }
        }
    }
}

#Preview {
    MainTabView()
}
