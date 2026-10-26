import SwiftUI
import os.log

/// Each tab owns its `NavigationStack`, so a push stays inside its tab and the tab bar stays
/// visible. A single `NavigationView` around the whole `TabView` used to own every tab's title
/// and pushes, and `LearnView` nested a second one inside it (second-audit D1a).
struct MainView: View {
    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
            }
            .tabItem {
                Label("Sleep", systemImage: "moon.zzz")
            }
            .accessibilityLabel("Sleep Dashboard")
            .accessibilityHint("View recorded sleep data, available estimates, and recent sessions")
            .accessibilityIdentifier("sleepTab")

            NavigationStack {
                AlarmSettingsView()
            }
            .tabItem {
                Label("Alarm", systemImage: "alarm.fill")
            }
            .accessibilityLabel("Alarm Settings")
            .accessibilityHint("Manage your smart alarms and wake-up settings")
            .accessibilityIdentifier("alarmTab")

            NavigationStack {
                LearnView()
            }
            .tabItem {
                Label("Learn", systemImage: "book.fill")
            }
            .accessibilityLabel("Learn")
            .accessibilityHint("Explore educational content about sleep health and habits")
            .accessibilityIdentifier("learnTab")
        }
    }
}

#if DEBUG
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
#endif
