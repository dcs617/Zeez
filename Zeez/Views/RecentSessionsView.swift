import SwiftUI
import CoreData
import os.log

struct RecentSessionsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedSession: SleepSession?
    
    @FetchRequest<SleepSession>(
        sortDescriptors: [NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: false)],
        predicate: NSPredicate(format: "isActive == NO"),
        animation: .default
    ) private var sessions
    
    private var sessionsArray: [SleepSession] {
        Array(sessions)
    }
    
    var body: some View {
        List {
            ForEach(Array(sessionsArray.enumerated()), id: \.element.id) { index, session in
                Button {
                    selectedSession = session
                } label: {
                    SessionRow(session: session)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .accessibilityLabel("Sleep session \(index + 1), \(sessionAccessibilityLabel(session))")
                .accessibilityHint("Tap to view detailed sleep analysis")
                .accessibilityIdentifier("sleepSession_\(index)")
            }
        }
        .navigationTitle("Sleep History")
        .sheet(item: $selectedSession) { session in
            NavigationView {
                EnhancedSleepDetailsView(session: session)
            }
        }
        .accessibilityIdentifier("recentSessionsView")
    }
    
    private func sessionAccessibilityLabel(_ session: SleepSession) -> String {
        var components: [String] = []
        
        if let startTime = session.startTime {
            components.append("started \(startTime.formatted(date: .abbreviated, time: .shortened))")
        }
        
        if let endTime = session.endTime {
            components.append("ended \(endTime.formatted(date: .abbreviated, time: .shortened))")
        }
        
        if session.qualityScore > 0 {
            components.append("quality score \(Int(session.qualityScore))")
        }
        
        return components.joined(separator: ", ")
    }
}

#Preview {
    NavigationView {
        RecentSessionsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
