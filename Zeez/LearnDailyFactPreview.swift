import SwiftUI
import CoreData

struct LearnDailyFactPreview: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest<SleepFact>(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \SleepFact.lastShownDate, ascending: true)
        ],
        predicate: NSPredicate(format: "timesShown < 3"),
        animation: .default
    ) private var facts
    
    private var factsArray: [SleepFact] {
        Array(facts)
    }
    
    var body: some View {
        if let fact = factsArray.first {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Today's Sleep Fact")
                        .font(.headline)
                }
                
                Text(fact.title ?? "")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(fact.content ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

#Preview {
    LearnDailyFactPreview()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}