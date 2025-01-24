import SwiftUI
import CoreData

struct LearnDailyFactView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest<SleepFact>(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \SleepFact.lastShownDate, ascending: true)
        ],
        predicate: NSPredicate(value: true)
    ) private var facts
    
    @State private var currentFact: SleepFact?
    @State private var showingAllFacts = false
    @State private var isAnimating = false
    
    private var factsArray: [SleepFact] {
        Array(facts)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let fact = currentFact {
                factCard(fact)
            } else {
                loadingView
            }
            
            factsList
        }
        .navigationTitle("Did You Know?")
        .onAppear {
            loadTodaysFact()
        }
    }
    
    private func factCard(_ fact: SleepFact) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Today's Sleep Fact")
                    .font(.headline)
                Spacer()
                Button(action: loadNewFact) {
                    Image(systemName: "arrow.clockwise")
                }
            }
            
            Text(fact.title ?? "")
                .font(.title3)
                .fontWeight(.bold)
            
            Text(fact.content ?? "")
                .font(.body)
                .lineSpacing(4)
            
            if let source = fact.source {
                Text("Source: \(source)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                if let category = fact.category {
                    Text(category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
                Spacer()
                Button("Share") {
                    shareFact(fact)
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .padding()
        .opacity(isAnimating ? 1 : 0)
        .offset(x: isAnimating ? 0 : 50)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                isAnimating = true
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading today's fact...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var factsList: some View {
        VStack {
            Button(action: { showingAllFacts.toggle() }) {
                HStack {
                    Text(showingAllFacts ? "Hide Previous Facts" : "Show Previous Facts")
                    Image(systemName: showingAllFacts ? "chevron.up" : "chevron.down")
                }
                .padding()
            }
            
            if showingAllFacts {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(factsArray) { fact in
                            if fact != currentFact {
                                previousFactCard(fact)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
    
    private func previousFactCard(_ fact: SleepFact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(fact.title ?? "")
                .font(.headline)
            
            Text(fact.content ?? "")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            if let lastShown = fact.lastShownDate {
                Text("Shown on \(lastShown.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func loadTodaysFact() {
        // First, try to get today's fact if already shown
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let existingFact = factsArray.first(where: { fact in
            if let lastShown = fact.lastShownDate {
                return calendar.isDate(lastShown, inSameDayAs: today)
            }
            return false
        }) {
            currentFact = existingFact
            return
        }
        
        // Otherwise, get a new fact
        loadNewFact()
    }
    
    private func loadNewFact() {
        // Reset animation state
        isAnimating = false
        
        // Get least recently shown fact
        if let newFact = factsArray.first {
            newFact.timesShown = Int16(Int(newFact.timesShown) + 1)
            newFact.lastShownDate = Date()
            
            do {
                try viewContext.save()
                withAnimation {
                    currentFact = newFact
                }
                
                // Trigger appear animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        isAnimating = true
                    }
                }
            } catch {
                print("Error updating fact: \(error)")
            }
        }
    }
    
    private func shareFact(_ fact: SleepFact) {
        guard let title = fact.title,
              let content = fact.content else { return }
        
        let shareText = """
        Did you know? 🌙
        
        \(title)
        
        \(content)
        
        Learn more about sleep with Zeez
        """
        
        let av = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        // Get the window scene and present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(av, animated: true)
        }
    }
}

#Preview {
    NavigationView {
        LearnDailyFactView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}