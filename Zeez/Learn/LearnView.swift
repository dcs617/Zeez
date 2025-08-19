import SwiftUI
import CoreData
import os.log

struct LearnView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedTab: LearnTab = .articles
    @State private var showingSearch = false
    @State private var showingBookmarks = false
    @State private var showingSettings = false
    @State private var showingQuickNote = false
    @AppStorage("hasShownLearnOnboarding") private var hasShownOnboarding = false
    
    enum LearnTab: String, CaseIterable, Identifiable {
        case articles = "Articles"
        case tools = "Tools"
        case challenges = "Challenges"
        case progress = "Progress"
        
        var id: Self { self }
        
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
                // Modern Tab Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(LearnTab.allCases) { tab in
                            VStack(spacing: 8) {
                                Image(systemName: tab.icon)
                                    .font(.title2)
                                    .foregroundColor(selectedTab == tab ? .blue : .gray)
                                Text(tab.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(selectedTab == tab ? .primary : .gray)
                                
                                if selectedTab == tab {
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(height: 2)
                                        .matchedGeometryEffect(id: "activeTab", in: namespace)
                                } else {
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(height: 2)
                                }
                            }
                            .frame(width: 80)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedTab = tab
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(tab.rawValue) tab")
                            .accessibilityHint(selectedTab == tab ? "Currently selected" : "Switch to \(tab.rawValue) section")
                            .accessibilityIdentifier("learnTab_\(tab.rawValue.lowercased())")
                            .accessibilityAddTraits(selectedTab == tab ? [.isSelected] : [])
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                Divider()
                
                // Main Content Area with TabView for smooth transitions
                TabView(selection: $selectedTab) {
                    ForEach(LearnTab.allCases) { tab in
                        Group {
                            switch tab {
                            case .articles:
                                ArticlesTabView()
                            case .tools:
                                LearnToolsView()
                            case .challenges:
                                LearnChallengeListView()
                            case .progress:
                                ProgressTabView()
                            }
                        }
                        .tag(tab)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Learn")
                        .font(.title3.bold())
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: LearnPathNavigator()) {
                        Label("Learning Path", systemImage: "map.fill")
                    }
                    .accessibilityLabel("Learning Path")
                    .accessibilityHint("Navigate to structured learning pathways")
                    .accessibilityIdentifier("learningPathButton")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if selectedTab == .articles || selectedTab == .progress {
                            Button(action: { showingQuickNote = true }) {
                                Label("Quick Note", systemImage: "square.and.pencil")
                            }
                            .accessibilityLabel("Quick Note")
                            .accessibilityHint("Create a quick note about your learning")
                            .accessibilityIdentifier("quickNoteButton")
                        }
                        
                        NavigationLink(destination: LearnAchievementView()) {
                            Label("Achievements", systemImage: "star.fill")
                        }
                        .accessibilityLabel("Achievements")
                        .accessibilityHint("View your learning achievements and milestones")
                        .accessibilityIdentifier("achievementsLink")
                        
                        Button(action: { showingBookmarks = true }) {
                            Label("Bookmarks", systemImage: "bookmark.fill")
                        }
                        .accessibilityLabel("Bookmarks")
                        .accessibilityHint("View your saved articles and content")
                        .accessibilityIdentifier("bookmarksButton")
                        
                        Button(action: { showingSearch = true }) {
                            Label("Search", systemImage: "magnifyingglass")
                        }
                        .accessibilityLabel("Search")
                        .accessibilityHint("Search through learning content and articles")
                        .accessibilityIdentifier("searchButton")
                        
                        Button(action: { showingSettings = true }) {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                        .accessibilityLabel("Learn Settings")
                        .accessibilityHint("Configure learning preferences and options")
                        .accessibilityIdentifier("learnSettingsButton")
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                    .accessibilityLabel("Learn menu")
                    .accessibilityHint("Opens menu with additional learning options")
                    .accessibilityIdentifier("learnMenuButton")
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
    
    @Namespace private var namespace
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
            .accessibilityLabel("Progress view selector")
            .accessibilityHint("Choose between progress tracking and learning statistics")
            .accessibilityIdentifier("progressViewPicker")
            
            if selectedView == "Progress" {
                LearnProgressView()
                    .transition(.opacity)
            } else {
                LearnStatisticsView()
                    .transition(.opacity)
            }
        }
    }
}

struct ArticlesTabView: View {
    var body: some View {
        LearnArticleListView(category: .basics) { _ in }
    }
}

#Preview {
    LearnView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
