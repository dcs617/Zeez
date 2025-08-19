import SwiftUI
import CoreData
import os.log

struct LearnChallengeDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    let challengeId: NSManagedObjectID
    @State private var showingJoinAlert = false
    @State private var showingCompletionAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let challenge = fetchChallenge() {
                    VStack(alignment: .leading, spacing: 20) {
                        challengeHeader(challenge)
                        challengeProgress(challenge)
                        challengeDescription(challenge)
                        challengeRequirements(challenge)
                        relatedArticles(challenge)
                        
                        if let progress = challenge.userProgress, !progress.isCompleted {
                            actionButton(for: challenge)
                        }
                    }
                    .padding()
                } else {
                    errorView
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Challenge details view")
            .accessibilityHint("View details and manage challenge participation")
            .accessibilityIdentifier("challengeDetailScrollView")
            .navigationTitle("Challenge Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                    .accessibilityLabel("Done")
                    .accessibilityHint("Close challenge details")
                    .accessibilityIdentifier("challengeDetailDoneButton")
                }
            }
            .alert("Join Challenge", isPresented: $showingJoinAlert) {
                Button("Start") { joinChallenge() }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let challenge = fetchChallenge() {
                    Text("Are you ready to start this \(challenge.durationDays) day challenge?")
                }
            }
            .alert("Complete Challenge", isPresented: $showingCompletionAlert) {
                Button("Complete", role: .destructive) { completeChallenge() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Have you completed all requirements for this challenge?")
            }
        }
    }
    
    private func challengeHeader(_ challenge: LearnChallenge) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(challenge.title ?? "Untitled Challenge")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Challenge: \(challenge.title ?? "Untitled Challenge")")
                .accessibilityIdentifier("challengeTitle")
            
            HStack {
                Label("\(challenge.durationDays) days", systemImage: "calendar")
                .accessibilityLabel("Duration: \(challenge.durationDays) days")
                .accessibilityHint("Challenge duration in days")
                .accessibilityIdentifier("challengeDuration")
                Spacer()
                Label("\(challenge.points) points", systemImage: "star.fill")
                    .foregroundColor(.orange)
                    .accessibilityLabel("Points: \(challenge.points)")
                    .accessibilityHint("Points earned for completing this challenge")
                    .accessibilityIdentifier("challengePoints")
            }
            .font(.subheadline)
            
            if challenge.isActive {
                HStack {
                    Image(systemName: "clock")
                    Text("Started \(challenge.startDate ?? Date(), style: .date)")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Divider()
        }
    }
    
    private func challengeProgress(_ challenge: LearnChallenge) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Progress section")
                .accessibilityIdentifier("progressHeader")
            
            if let progress = challenge.userProgress {
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: progress.progress)
                        .tint(.blue)
                        .accessibilityLabel("Challenge progress: \(Int(progress.progress * 100)) percent complete")
                        .accessibilityIdentifier("challengeProgressBar")
                    
                    Text("\(Int(progress.progress * 100))% Complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
            } else {
                Text("Not Started")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func challengeDescription(_ challenge: LearnChallenge) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About this Challenge")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("About this challenge section")
                .accessibilityIdentifier("challengeDescriptionHeader")
            
            Text(challenge.description)
                .font(.body)
                .lineSpacing(4)
                .accessibilityLabel("Challenge description: \(challenge.description)")
                .accessibilityIdentifier("challengeDescriptionText")
        }
    }
    
    private func challengeRequirements(_ challenge: LearnChallenge) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Requirements")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Requirements section")
                .accessibilityIdentifier("requirementsHeader")
            
            if let requirements = challenge.requirements {
                let decoder = JSONDecoder()
                if let requirements = try? decoder.decode([String].self, from: requirements) {
                    ForEach(requirements, id: \.self) { requirement in
                        HStack(alignment: .top) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .padding(.top, 6)
                            Text(requirement)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Requirement: \(requirement)")
                        .accessibilityIdentifier("requirement_\(requirement.prefix(20).replacingOccurrences(of: " ", with: "_"))")
                    }
                }
            }
        }
    }
    
    private func relatedArticles(_ challenge: LearnChallenge) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let articles = challenge.relatedArticles?.allObjects as? [LearnArticle], !articles.isEmpty {
                Text("Related Articles")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityLabel("Related articles section")
                    .accessibilityIdentifier("relatedArticlesHeader")
                
                ForEach(articles) { article in
                    NavigationLink(destination: LearnArticleDetailView(articleId: article.objectID)) {
                        HStack {
                            Text(article.title ?? "Untitled Article")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Related article: \(article.title ?? "Untitled Article")")
                    .accessibilityHint("Navigate to article")
                    .accessibilityIdentifier("relatedArticle_\(article.title?.replacingOccurrences(of: " ", with: "_") ?? "untitled")")
                }
            }
        }
    }
    
    private func actionButton(for challenge: LearnChallenge) -> some View {
        Button(action: {
            if challenge.isActive {
                showingCompletionAlert = true
            } else {
                showingJoinAlert = true
            }
        }) {
            Text(challenge.isActive ? "Mark as Complete" : "Start Challenge")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(challenge.isActive ? Color.green : Color.blue)
                .cornerRadius(12)
        }
        .accessibilityLabel(challenge.isActive ? "Mark challenge as complete" : "Start challenge")
        .accessibilityHint(challenge.isActive ? "Mark this challenge as completed" : "Begin participating in this challenge")
        .accessibilityIdentifier("challengeActionButton")
        .padding(.top)
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Challenge Not Found")
                .font(.headline)
            
            Text("This challenge may have been removed or is temporarily unavailable.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Challenge not found")
        .accessibilityHint("This challenge may have been removed or is temporarily unavailable")
        .accessibilityIdentifier("challengeNotFoundView")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func fetchChallenge() -> LearnChallenge? {
        viewContext.object(with: challengeId) as? LearnChallenge
    }
    
    private func joinChallenge() {
        guard let challenge = fetchChallenge() else { return }
        
        challenge.isActive = true
        challenge.startDate = Date()
        challenge.endDate = Calendar.current.date(byAdding: .day, value: Int(challenge.durationDays), to: Date())
        
        let progress = ChallengeBadge(context: viewContext)
        progress.challenge = challenge
        progress.progress = 0
        progress.isCompleted = false
        
        do {
            try viewContext.save()
        } catch {
            ZeezLogger.error(ZeezLogger.learning, "Error joining challenge", error: error)
        }
    }
    
    private func completeChallenge() {
        guard let challenge = fetchChallenge(),
              let progress = challenge.userProgress else { return }
        
        progress.isCompleted = true
        progress.progress = 1.0
        progress.earnedDate = Date()
        
        do {
            try viewContext.save()
        } catch {
            ZeezLogger.error(ZeezLogger.learning, "Error completing challenge", error: error)
        }
    }
}

#Preview {
    LearnChallengeDetailView(challengeId: NSManagedObjectID())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
