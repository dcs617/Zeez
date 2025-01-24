import SwiftUI
import CoreData

struct LearnHomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var navigationPath = NavigationPath()
    @State private var searchText = ""
    @State private var showingQuickNote = false
    @State private var showingSearch = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                searchBar
                
                ScrollView {
                    VStack(spacing: 24) {
                        LearnDailyFactPreview()
                            .onTapGesture {
                                navigationPath.append(Route.dailyFact)
                            }
                        
                        categoriesGrid
                        
                        progressSection
                        
                        notesSection
                        
                        toolsSection
                        
                        practiceSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Learn")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .dailyFact:
                    LearnDailyFactView()
                case .articles(let category):
                    LearnArticleListView(category: category) { _ in }
                case .notes:
                    LearnNoteBrowserView()
                case .highlights:
                    LearnNoteBrowserView(initialFilter: .highlights)
                case .bookmarks:
                    LearnBookmarksView()
                case .statistics:
                    LearnStatisticsView()
                case .sleepCycles:
                    LearnSleepCycleAnimation()
                case .circadianRhythm:
                    LearnCircadianRhythmView()
                case .brainActivity:
                    LearnBrainActivityVisualizer()
                case .environmentalImpact:
                    LearnEnvironmentalImpactView()
                case .sleepPositions:
                    LearnSleepPositionView()
                case .sleepDebt:
                    LearnSleepDebtView()
                case .sleepStages:
                    LearnSleepStageComparisonView()
                case .glossary:
                    LearnGlossaryView()
                }
            }
            .sheet(isPresented: $showingQuickNote) {
                LearnQuickNoteView()
            }
            .sheet(isPresented: $showingSearch) {
                NavigationView {
                    LearnSearchView()
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            Button(action: { showingSearch = true }) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    Text("Search articles, notes, and tools")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            Button(action: { showingQuickNote = true }) {
                Image(systemName: "square.and.pencil")
                    .foregroundColor(.blue)
            }
        }
        .padding()
    }
    
    private var categoriesGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(LearnCategory.allCases, id: \.self) { category in
                    Button {
                        navigationPath.append(Route.articles(category))
                    } label: {
                        CategoryCard(category: category)
                    }
                }
            }
        }
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Progress")
                    .font(.headline)
                Spacer()
                Button {
                    navigationPath.append(Route.statistics)
                } label: {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            
            Button {
                navigationPath.append(Route.bookmarks)
            } label: {
                ToolCard(
                    title: "Bookmarked Articles",
                    icon: "bookmark.fill",
                    color: .blue,
                    description: "Continue where you left off"
                )
            }
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notes & Highlights")
                .font(.headline)
            
            VStack(spacing: 12) {
                Button {
                    navigationPath.append(Route.notes)
                } label: {
                    ToolCard(
                        title: "All Notes",
                        icon: "note.text",
                        color: .blue,
                        description: "Your thoughts and insights"
                    )
                }
                
                Button {
                    navigationPath.append(Route.highlights)
                } label: {
                    ToolCard(
                        title: "Highlights",
                        icon: "highlighter",
                        color: .yellow,
                        description: "Important passages you've saved"
                    )
                }
            }
        }
    }
    
    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Learning Tools")
                .font(.headline)
            
            VStack(spacing: 12) {
                Button {
                    navigationPath.append(Route.sleepCycles)
                } label: {
                    ToolCard(
                        title: "Sleep Cycles",
                        icon: "waveform.path.ecg",
                        color: .purple,
                        description: "Understand your sleep stages"
                    )
                }
                
                Button {
                    navigationPath.append(Route.circadianRhythm)
                } label: {
                    ToolCard(
                        title: "Circadian Rhythm",
                        icon: "clock",
                        color: .orange,
                        description: "Your body's natural clock"
                    )
                }
                
                Button {
                    navigationPath.append(Route.brainActivity)
                } label: {
                    ToolCard(
                        title: "Brain Activity",
                        icon: "brain.head.profile",
                        color: .pink,
                        description: "Brain waves during sleep"
                    )
                }
                
                Button {
                    navigationPath.append(Route.environmentalImpact)
                } label: {
                    ToolCard(
                        title: "Environmental Impact",
                        icon: "thermometer.sun",
                        color: .green,
                        description: "How your environment affects sleep"
                    )
                }
            }
        }
    }
    
    private var practiceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Practice & Reference")
                .font(.headline)
            
            VStack(spacing: 12) {
                Button {
                    navigationPath.append(Route.sleepPositions)
                } label: {
                    ToolCard(
                        title: "Sleep Positions",
                        icon: "figure.walk",
                        color: .blue,
                        description: "Find your optimal sleeping position"
                    )
                }
                
                Button {
                    navigationPath.append(Route.sleepDebt)
                } label: {
                    ToolCard(
                        title: "Sleep Debt",
                        icon: "chart.pie",
                        color: .red,
                        description: "Calculate and recover sleep debt"
                    )
                }
                
                Button {
                    navigationPath.append(Route.sleepStages)
                } label: {
                    ToolCard(
                        title: "Sleep Stages",
                        icon: "chart.bar.doc.horizontal",
                        color: .teal,
                        description: "Compare REM and Deep Sleep"
                    )
                }
                
                Button {
                    navigationPath.append(Route.glossary)
                } label: {
                    ToolCard(
                        title: "Sleep Glossary",
                        icon: "book.closed",
                        color: .indigo,
                        description: "Key terms and definitions"
                    )
                }
            }
        }
    }
}

enum Route: Hashable {
    case dailyFact
    case articles(LearnCategory)
    case notes
    case highlights
    case bookmarks
    case statistics
    case sleepCycles
    case circadianRhythm
    case brainActivity
    case environmentalImpact
    case sleepPositions
    case sleepDebt
    case sleepStages
    case glossary
}

struct CategoryCard: View {
    let category: LearnCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: category.systemIcon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(category.rawValue)
                .font(.headline)
            
            Text(category.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationView {
        LearnHomeView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}