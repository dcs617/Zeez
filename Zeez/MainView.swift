import SwiftUI

/// Main tab-based interface for the Zeez sleep tracking app
struct MainView: View {
    @State private var selectedTab = Tab.dashboard
    @StateObject private var errorManager = ErrorManager.shared
    
    // Using an enum for type-safe tab selection
    private enum Tab {
        case rise
        case dream
        case dashboard
        case stats
        case trends
    }
    
    var body: some View {
        // Using NavigationView at the root level ensures consistent navigation behavior
        NavigationView {
            TabView(selection: $selectedTab) {
                NavigationView {
                    RiseView()
                        .navigationBarHidden(true)
                }
                .tabItem {
                    Label("Rise", systemImage: "alarm")
                        .environment(\.symbolVariants, .none)
                }
                .tag(Tab.rise)
                
                NavigationView {
                    DreamView()
                        .navigationBarHidden(true)
                }
                .tabItem {
                    Label("Dream", systemImage: "cloud.moon")
                        .environment(\.symbolVariants, .none)
                }
                .tag(Tab.dream)
                
                NavigationView {
                    DashboardView()
                        .navigationBarHidden(true)
                }
                .tabItem {
                    Label("Sleep", systemImage: "moon.stars")
                        .environment(\.symbolVariants, .none)
                }
                .tag(Tab.dashboard)
                
                NavigationView {
                    StatsView()
                        .navigationBarHidden(true)
                }
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                        .environment(\.symbolVariants, .none)
                }
                .tag(Tab.stats)
                
                NavigationView {
                    TrendsView()
                        .navigationBarHidden(true)
                }
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                        .environment(\.symbolVariants, .none)
                }
                .tag(Tab.trends)
            }
            .accentColor(.purple) // Ensures consistent tab selection color
            .onAppear {
                // Configure tab bar appearance
                let appearance = UITabBarAppearance()
                appearance.configureWithTransparentBackground()
                
                // Keep icons small and use consistent colors
                appearance.stackedLayoutAppearance.normal.iconColor = .systemGray
                appearance.stackedLayoutAppearance.selected.iconColor = .systemPurple
                
                // Set font sizes for tab labels
                appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                    .font: UIFont.systemFont(ofSize: 10)
                ]
                appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                    .font: UIFont.systemFont(ofSize: 10)
                ]
                
                // Apply appearance settings
                UITabBar.appearance().standardAppearance = appearance
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
    }
}

/// Rise tab view for alarm management
struct RiseView: View {
    var body: some View {
        AlarmSettingsView()
            .navigationTitle("Rise")
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
