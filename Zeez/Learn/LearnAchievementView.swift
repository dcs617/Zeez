import SwiftUI
import CoreData
import os.log

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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                achievementStats
                recentBadges
                allBadges
            }
            .padding()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Achievements view")
        .accessibilityHint("View your earned badges and achievement statistics")
        .accessibilityIdentifier("achievementsScrollView")
        .sheet(item: $selectedBadge) { badge in
            BadgeDetailView(badge: badge)
        }
    }
    
    private var achievementStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Achievements section")
                .accessibilityIdentifier("achievementsHeader")
            
            HStack(spacing: 20) {
                statCard(
                    title: "Badges Earned",
                    value: "\(badgesArray.count)",
                    icon: "star.fill",
                    color: Color.yellow
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Badges earned: \(badgesArray.count)")
                .accessibilityHint("Total number of achievement badges you have earned")
                .accessibilityIdentifier("badgesEarnedCard")
                
                statCard(
                    title: "Total Points",
                    value: "\(calculateTotalPoints())",
                    icon: "trophy.fill",
                    color: Color.orange
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Total points: \(calculateTotalPoints())")
                .accessibilityHint("Total achievement points you have earned")
                .accessibilityIdentifier("totalPointsCard")
            }
        }
    }
    
    private var recentBadges: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Achievements")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Recent achievements section")
                .accessibilityIdentifier("recentAchievementsHeader")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(badgesArray.prefix(5), id: \.self) { badge in
                        BadgeCard(badge: badge)
                            .onTapGesture {
                                selectedBadge = badge
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Badge: \(badge.challenge?.title ?? "Unknown")")
                            .accessibilityHint("Double tap to view badge details")
                            .accessibilityIdentifier("recentBadge_\(badge.challenge?.title?.replacingOccurrences(of: " ", with: "_") ?? "unknown")")
                    }
                }
            }
        }
    }
    
    private var allBadges: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Badges")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("All badges section")
                .accessibilityIdentifier("allBadgesHeader")
            
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
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Badge: \(badge.challenge?.title ?? "Unknown")")
                        .accessibilityHint("Double tap to view badge details")
                        .accessibilityIdentifier("badge_\(badge.challenge?.title?.replacingOccurrences(of: " ", with: "_") ?? "unknown")")
                }
            }
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Achievement badge: \(badge.challenge?.title ?? "Unknown badge")")
        .accessibilityHint("Earned on \(badge.earnedDate?.formatted(date: .abbreviated, time: .omitted) ?? "unknown date")")
        .accessibilityIdentifier("badgeCard_\(badge.challenge?.title?.replacingOccurrences(of: " ", with: "_") ?? "unknown")")
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
                        .accessibilityLabel("Large badge display: \(badge.challenge?.title ?? "Unknown badge")")
                        .accessibilityHint("Achievement badge earned on \(badge.earnedDate?.formatted(date: .abbreviated, time: .omitted) ?? "unknown date")")
                        .accessibilityIdentifier("largeBadgeDisplay")
                    
                    VStack(spacing: 12) {
                        Text(badge.challenge?.title ?? "")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityLabel("Badge title: \(badge.challenge?.title ?? "Unknown")")
                            .accessibilityIdentifier("badgeDetailTitle")
                        
                        Text("Earned \(badge.earnedDate ?? Date(), style: .date)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Badge earned on \(badge.earnedDate?.formatted(date: .complete, time: .omitted) ?? "unknown date")")
                            .accessibilityIdentifier("badgeEarnedDate")
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Challenge Description")
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityLabel("Challenge description section")
                            .accessibilityIdentifier("challengeDescriptionHeader")
                        
                        Text(badge.challenge?.challengeDescription ?? "")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .accessibilityLabel("Description: \(badge.challenge?.challengeDescription ?? "No description available")")
                            .accessibilityIdentifier("challengeDescription")
                        
                        if let points = badge.challenge?.points {
                            HStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text("\(points) points earned")
                                    .font(.subheadline)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Points earned: \(points)")
                            .accessibilityHint("Achievement points for completing this challenge")
                            .accessibilityIdentifier("pointsEarned")
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
                    .accessibilityLabel("Done")
                    .accessibilityHint("Close badge details")
                    .accessibilityIdentifier("badgeDetailDoneButton")
                }
            }
        }
    }
}

#Preview {
    LearnAchievementView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}