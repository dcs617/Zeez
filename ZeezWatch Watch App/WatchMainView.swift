import SwiftUI

struct WatchMainView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    
    var body: some View {
        TabView {
            // Sleep Summary Tab
            SleepSummaryView()
                .tabItem {
                    Image(systemName: "moon.fill")
                    Text("Sleep")
                }
                .tag(0)
            
            // Alarm Control Tab
            AlarmControlView()
                .tabItem {
                    Image(systemName: "alarm.fill")
                    Text("Alarm")
                }
                .tag(1)
            
            // Settings/Status Tab
            WatchSettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(2)
        }
        .onAppear {
            // Request initial data when app appears
            connectivityManager.requestLatestData()
        }
    }
}

#Preview {
    WatchMainView()
}