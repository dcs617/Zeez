import SwiftUI
import os.log

struct MainView: View {
    var body: some View {
        NavigationView {
            TabView {
                DashboardView()
                    .tabItem {
                        Label("Sleep", systemImage: "moon.zzz")
                    }
                    .accessibilityLabel("Sleep Dashboard")
                    .accessibilityHint("View your sleep data, quality metrics, and recent sleep sessions")
                    .accessibilityIdentifier("sleepTab")
                
                AlarmSettingsView()
                    .tabItem {
                        Label("Alarm", systemImage: "alarm.fill")
                    }
                    .accessibilityLabel("Alarm Settings")
                    .accessibilityHint("Manage your smart alarms and wake-up settings")
                    .accessibilityIdentifier("alarmTab")

                LearnView()
                    .tabItem {
                        Label("Learn", systemImage: "book.fill")
                    }
                    .accessibilityLabel("Learn")
                    .accessibilityHint("Explore educational content about sleep health and habits")
                    .accessibilityIdentifier("learnTab")
            }
        }
        .navigationViewStyle(.stack)
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
