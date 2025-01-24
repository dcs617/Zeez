import SwiftUI
import CoreData

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
            ForEach(sessionsArray) { session in
                Button {
                    selectedSession = session
                } label: {
                    SessionRow(session: session)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .navigationTitle("Sleep History")
        .sheet(item: $selectedSession) { session in
            NavigationView {
                EnhancedSleepDetailsView(session: session)
            }
        }
    }
}

#Preview {
    NavigationView {
        RecentSessionsView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}