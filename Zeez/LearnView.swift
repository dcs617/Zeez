import SwiftUI
import CoreData

struct LearnView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab = LearnTab.articles
    @State private var showingSearch = false
    @State private var showingBookmarks = false
    @State private var showingSettings = false
    @State private var showingQuickNote = false
    @State private var isTransitioning = false
    @AppStorage("hasShownLearnOnboarding") private var hasShownOnboarding = false
    
    enum LearnTab: String, CaseIterable {
        case articles = "Articles"
        case tools = "Tools"
        case challenges = "Challenges"
        case progress = "Progress"
        
        var icon: String {
            switch self {
            case .articles: return "book.fill"
            case .tools: return "wrench.and.screwdriver.fill"
            case .challenges: return "trophy.fill"
            case .progress: return "chart.bar.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(LearnTab.allCases, id: \.self) { tab in
                            TabButton(
                                title: tab.rawValue,
                                icon: tab.icon,
                                isSelected: selectedTab == tab
                            ) {
                                withAnimation {
                                    isTransitioning = true
                                    selectedTab = tab
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                
                // Main content with transitions
                Group {
                    switch selectedTab {
                    case .articles:
                        ArticlesTabView()
                            .slideTransition(from: .trailing, active: isTransitioning)
                    case .tools:
                        LearnToolsView()
                            .slideTransition(from: .trailing, active: isTransitioning)
                    case .challenges:
                        LearnChallengeListView()
                            .slideTransition(from: .trailing, active: isTransitioning)
                    case .progress:
                        ProgressTabView()
                            .slideTransition(from: .trailing, active: isTransitioning)
                    }
                }
                .onChange(of: selectedTab) { _ in
                    // Reset transition state after animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isTransitioning = false
                    }
                }
            }
            .navigationTitle("Learn")
            .achievementOverlay()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: LearnPathNavigator()) {
                        Image(systemName: "map")
                            .fadeInTransition()
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    if selectedTab == .articles || selectedTab == .progress {
                        Button(action: { showingQuickNote = true }) {
                            Image(systemName: "square.and.pencil")
                                .fadeInTransition()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        NavigationLink(destination: LearnAchievementView()) {
                            Image(systemName: "star.fill")
                                .fadeInTransition()
                        }
                        
                        Button(action: { showingBookmarks = true }) {
                            Image(systemName: "bookmark")
                                .fadeInTransition()
                        }
                        
                        Button(action: { showingSearch = true }) {
                            Image(systemName: "magnifyingglass")
                                .fadeInTransition()
                        }
                        
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "gearshape")
                                .fadeInTransition()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSearch) {
                LearnSearchView()
            }
            .sheet(isPresented: $showingBookmarks) {
                NavigationView {
                    LearnBookmarksView()
                }
            }
            .sheet(isPresented: $showingSettings) {
                NavigationView {
                    LearnSettingsView()
                }
            }
            .sheet(isPresented: $showingQuickNote) {
                NavigationView {
                    LearnQuickNoteView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .fullScreenCover(isPresented: .init(
                get: { !hasShownOnboarding },
                set: { hasShownOnboarding = !$0 }
            )) {
                LearnOnboardingView()
            }
        }
    }
}

struct ProgressTabView: View {
    @State private var selectedView: String = "Progress"
    
    var body: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $selectedView) {
                Text("Progress").tag("Progress")
                Text("Statistics").tag("Statistics")
            }
            .pickerStyle(.segmented)
            .padding()
            
            if selectedView == "Progress" {
                LearnProgressView()
                    .fadeInTransition(active: selectedView != "Progress")
            } else {
                LearnStatisticsView()
                    .fadeInTransition(active: selectedView != "Statistics")
            }
        }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .scaleEffect(isHovered ? 1.1 : 1.0)
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .blue : .gray)
            .frame(width: 80)
            .padding(.vertical, 8)
        }
        .onHover { hovering in
            withAnimation(.spring()) {
                isHovered = hovering
            }
        }
    }
}

struct ArticlesTabView: View {
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                LearnProgressMiniWidget()
                    .padding(.horizontal)
                    .fadeInTransition(active: isLoading)
                
                ForEach(LearnCategory.allCases, id: \.self) { category in
                    NavigationLink(destination: LearnArticleListView(category: category) { _ in }) {
                        CategoryCard(category: category)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .fadeInTransition(active: isLoading)
                }
            }
            .padding(.vertical)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
                isLoading = false
            }
        }
        .onDisappear {
            isLoading = true
        }
    }
}

struct LearnView_Previews: PreviewProvider {
    static var previews: some View {
        LearnView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}