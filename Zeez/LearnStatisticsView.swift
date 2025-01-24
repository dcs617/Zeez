import SwiftUI
import CoreData

struct LearnStatisticsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest<UserArticleProgress>(
        entity: UserArticleProgress.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \UserArticleProgress.lastReadDate, ascending: false)]
    ) private var progress
    
    @FetchRequest<SleepNote>(
        entity: SleepNote.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \SleepNote.createdAt, ascending: false)]
    ) private var notes
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                overviewSection
                readingStatsSection
                notesStatsSection
                weeklyActivitySection
            }
            .padding()
        }
        .navigationTitle("Learning Stats")
    }
    
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Articles Read",
                    value: "\(completedArticlesCount)",
                    icon: "book.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Notes Created",
                    value: "\(Array(notes).count)",
                    icon: "note.text",
                    color: .green
                )
            }
        }
    }
    
    private var readingStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reading Activity")
                .font(.headline)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Reading Streak",
                    value: "\(readingStreak)",
                    subtitle: "days",
                    icon: "flame.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Total Time",
                    value: totalReadingTime,
                    subtitle: "read",
                    icon: "clock.fill",
                    color: .purple
                )
            }
        }
    }
    
    private var notesStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Notes Breakdown")
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(noteCategories, id: \.name) { category in
                    HStack {
                        Text(category.name)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Text("\(category.count)")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var weeklyActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Activity")
                .font(.headline)
            
            HStack(spacing: 4) {
                ForEach(lastSevenDays, id: \.self) { day in
                    VStack {
                        let activity = activityCount(for: day)
                        Rectangle()
                            .fill(activityColor(for: activity))
                            .frame(width: 20, height: CGFloat(activity * 20))
                            .cornerRadius(4)
                        
                        Text(day.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 100)
        }
    }
    
    // MARK: - Helper Views
    
    private struct StatCard: View {
        let title: String
        let value: String
        var subtitle: String? = nil
        let icon: String
        let color: Color
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(color)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Computed Properties
    
    private var completedArticlesCount: Int {
        Array(progress).filter { $0.isCompleted }.count
    }
    
    private var readingStreak: Int {
        var streak = 0
        let calendar = Calendar.current
        var currentDate = Date()
        
        while let progressOnDate = Array(progress).first(where: { progress in
            calendar.isDate(progress.lastReadDate ?? Date(), inSameDayAs: currentDate)
        }) {
            streak += 1
            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            currentDate = previousDate
        }
        
        return streak
    }
    
    private var totalReadingTime: String {
        let minutes = Array(progress).reduce(0) { sum, progress in
            sum + Int(progress.article?.readTimeMinutes ?? 0)
        }
        
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = Double(minutes) / 60.0
            return String(format: "%.1fh", hours)
        }
    }
    
    private var noteCategories: [(name: String, count: Int)] {
        let categories = Dictionary(grouping: Array(notes)) { $0.category ?? "Uncategorized" }
        return categories.map { ($0.key, $0.value.count) }
            .sorted { $0.count > $1.count }
    }
    
    private var lastSevenDays: [Date] {
        (0...6).map { days in
            Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        }.reversed()
    }
    
    private func activityCount(for date: Date) -> Int {
        let calendar = Calendar.current
        let articlesRead = Array(progress).filter { progress in
            calendar.isDate(progress.lastReadDate ?? Date(), inSameDayAs: date)
        }.count
        
        let notesCreated = Array(notes).filter { note in
            calendar.isDate(note.createdAt ?? Date(), inSameDayAs: date)
        }.count
        
        return articlesRead + notesCreated
    }
    
    private func activityColor(for count: Int) -> Color {
        switch count {
        case 0: return Color(.systemGray5)
        case 1: return .blue.opacity(0.3)
        case 2: return .blue.opacity(0.6)
        default: return .blue
        }
    }
}

#Preview {
    NavigationView {
        LearnStatisticsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}