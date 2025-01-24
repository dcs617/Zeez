import SwiftUI
import CoreData

struct LearnProgressView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var overallProgress = 0.0
    @State private var categoryProgress: [LearnCategory: Double] = [:]
    @State private var currentStreak = 0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                streakCard
                
                NavigationLink(destination: LearnStatisticsView()) {
                    overallProgressCard
                }
                
                categoryProgressSection
                recentActivitySection
            }
            .padding()
        }
        .navigationTitle("Learning Progress")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: LearnStatisticsView()) {
                    Label("Statistics", systemImage: "chart.bar.fill")
                }
            }
        }
        .onAppear {
            updateProgress()
        }
    }
    
    private var streakCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading) {
                    Text("\(currentStreak) Day Streak")
                        .font(.headline)
                    
                    Text(streakMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var streakMessage: String {
        switch currentStreak {
        case 0:
            return "Start your learning streak today!"
        case 1:
            return "First day of your streak!"
        case 2...6:
            return "\(7 - currentStreak) more days until your first week!"
        default:
            return "Keep up the great work!"
        }
    }
    
    private var overallProgressCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Overall Progress")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LearnCircularProgressView(progress: overallProgress)
                .frame(width: 120, height: 120)
            
            Text("\(Int(overallProgress * 100))% Complete")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Tap for detailed statistics")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var categoryProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Category Progress")
                .font(.headline)
            
            ForEach(LearnCategory.allCases, id: \.self) { category in
                CategoryProgressRow(
                    category: category,
                    progress: categoryProgress[category] ?? 0
                )
            }
        }
    }
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.headline)
            
            RecentActivityList()
        }
    }
    
    private func updateProgress() {
        let tracker = LearnProgressTracker.shared
        
        overallProgress = tracker.calculateOverallProgress(context: viewContext)
        currentStreak = tracker.getCurrentStreak(context: viewContext)
        
        for category in LearnCategory.allCases {
            categoryProgress[category] = tracker.calculateOverallProgress(
                in: category,
                context: viewContext
            )
        }
    }
}

struct CategoryProgressRow: View {
    let category: LearnCategory
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: category.systemIcon)
                    .foregroundColor(category.iconColor)
                Text(category.rawValue)
                    .font(.headline)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress)
                .tint(category.iconColor)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

extension LearnCategory {
    var iconColor: Color {
        switch self {
        case .basics: return .blue
        case .optimization: return .green
        case .science: return .purple
        case .challenges: return .orange
        }
    }
}

struct LearnCircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 12)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(
                    lineWidth: 12,
                    lineCap: .round
                ))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.title2)
                .fontWeight(.semibold)
        }
    }
}

struct RecentActivityList: View {
    @FetchRequest<UserArticleProgress>(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \UserArticleProgress.lastReadDate, ascending: false)
        ],
        predicate: NSPredicate(format: "lastReadDate != nil"),
        animation: .default
    ) private var articleProgress
    
    @FetchRequest<QuizProgress>(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \QuizProgress.completedAt, ascending: false)
        ],
        predicate: NSPredicate(format: "completedAt != nil"),
        animation: .default
    ) private var quizProgress
    
    private var articleArray: [UserArticleProgress] {
        Array(articleProgress)
    }
    
    private var quizArray: [QuizProgress] {
        Array(quizProgress)
    }
    
    var body: some View {
        if articleArray.isEmpty && quizArray.isEmpty {
            Text("No recent activity")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        } else {
            ForEach(articleArray.prefix(3)) { progress in
                ActivityRow(
                    icon: "book.fill",
                    title: progress.article?.title ?? "",
                    date: progress.lastReadDate ?? Date(),
                    type: "Article Read"
                )
            }
            
            ForEach(quizArray.prefix(3)) { progress in
                ActivityRow(
                    icon: "checkmark.seal.fill",
                    title: progress.quiz?.title ?? "",
                    date: progress.completedAt ?? Date(),
                    type: "Quiz Completed",
                    detail: "\(progress.score)%"
                )
            }
        }
    }
}

struct ActivityRow: View {
    let icon: String
    let title: String
    let date: Date
    let type: String
    var detail: String? = nil
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                
                HStack {
                    Text(type)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let detail = detail {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(detail)
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            Text(date.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationView {
        LearnProgressView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}