import SwiftUI
import CoreData

struct LearnAchievementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest<ChallengeBadge>(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ChallengeBadge.earnedDate, ascending: false)
        ],
        predicate: NSPredicate(format: "isCompleted == YES"),
        animation: .default
    ) private var completedChallenges
    
    @State private var selectedBadge: ChallengeBadge?
    @State private var showingBadgeDetail = false
    
    private var badgesArray: [ChallengeBadge] {
        Array(completedChallenges)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                achievementStats
                recentBadges
                allBadges
            }
            .padding()
        }
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailView(badge: badge)
        }
    }
    
    private var achievementStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(spacing: 20) {
                statCard(
                    title: "Badges Earned",
                    value: "\(badgesArray.count)",
                    icon: "star.fill",
                    color: .yellow
                )
                
                statCard(
                    title: "Total Points",
                    value: "\(calculateTotalPoints())",
                    icon: "trophy.fill",
                    color: .orange
                )
            }
        }
    }
    
    private var recentBadges: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Achievements")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(badgesArray.prefix(5), id: \.self) { badge in
                        BadgeCard(badge: badge)
                            .onTapGesture {
                                selectedBadge = badge
                            }
                    }
                }
            }
        }
    }
    
    private var allBadges: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Badges")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(badgesArray, id: \.self) { badge in
                    BadgeCard(badge: badge)
                        .onTapGesture {
                            selectedBadge = badge
                        }
                }
            }
        }
    }
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func calculateTotalPoints() -> Int {
        badgesArray.reduce(0) { sum, badge in
            sum + Int(badge.challenge?.points ?? 0)
        }
    }
}

struct BadgeCard: View {
    let badge: ChallengeBadge
    @State private var showingShine = false
    
    var body: some View {
        VStack {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "star.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.yellow)
                )
                .overlay(
                    Circle()
                        .stroke(Color.yellow, lineWidth: 2)
                        .opacity(showingShine ? 0 : 1)
                        .scaleEffect(showingShine ? 1.5 : 1)
                )
            
            Text(badge.challenge?.title ?? "")
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                showingShine = true
            }
        }
    }
}

struct BadgeDetailView: View {
    let badge: ChallengeBadge
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    BadgeCard(badge: badge)
                        .scaleEffect(1.5)
                        .padding(.top, 40)
                    
                    VStack(spacing: 12) {
                        Text(badge.challenge?.title ?? "")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Earned \(badge.earnedDate ?? Date(), style: .date)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Challenge Description")
                            .font(.headline)
                        
                        Text(badge.challenge?.challengeDescription ?? "")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        if let points = badge.challenge?.points {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("\(points) points earned")
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    LearnAchievementView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}