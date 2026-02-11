import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var sessionManager: SessionManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "timer")
                }
                .tag(0)

            SocialView()
                .tabItem {
                    Label("Social", systemImage: "person.2")
                }
                .tag(1)

            TimeRequestsView()
                .tabItem {
                    Label("Requests", systemImage: "clock.arrow.circlepath")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
        }
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveDeepLink)) { notification in
            if let type = notification.userInfo?["type"] as? String {
                switch type {
                case "time_request":
                    selectedTab = 2
                case "friend_request":
                    selectedTab = 1
                default:
                    break
                }
            }
        }
    }
}
