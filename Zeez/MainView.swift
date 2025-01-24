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
        case learn
        case insights
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
                    LearnView()
                        .navigationBarHidden(true)
                }
                .tabItem {
                    Label("Learn", systemImage: "book.fill")
                        .environment(\.symbolVariants, .none)
                }
                .tag(Tab.learn)
                
                NavigationView {
                    TrendsView()
                        .navigationBarHidden(true)
                }
                .tabItem {
                    Label("Insights", systemImage: "chart.line.uptrend.xyaxis")
                        .environment(\.symbolVariants, .none)
                }
                .tag(Tab.insights)
            }
            .accentColor(.purple) // Ensures consistent tab selection color
            .onAppear {
                configureAppearance()
            }
        }
    }
    
    private func configureAppearance() {
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        
        // Keep icons small and use consistent colors
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = .systemGray
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = .systemPurple
        
        // Set font sizes for tab labels
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10)
        ]
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 10)
        ]
        
        // Apply tab bar appearance settings
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Configure navigation bar and status bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithOpaqueBackground()
        
        // Apply navigation bar appearance settings
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        
        // Configure scroll edge appearance for status bar
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.backgroundColor = .systemBackground
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