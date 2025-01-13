import SwiftUI
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: false)],
        predicate: NSPredicate(format: "isActive == NO"),
        animation: .default)
    private var recentSessions: FetchedResults<SleepSession>
    
    @FetchRequest(
        sortDescriptors: [],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default)
    private var activeSessions: FetchedResults<SleepSession>
    
    private var activeSession: SleepSession? {
        activeSessions.first
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let activeSession = activeSession {
                        ActiveSessionCard(session: activeSession)
                    } else {
                        StartSessionCard()
                    }
                    
                    if let lastSession = recentSessions.first {
                        LastNightCard(session: lastSession)
                    }
                    
                    WeeklyTrendCard(sessions: Array(recentSessions.prefix(7)))
                    
                    NextAlarmCard()
                }
                .padding()
            }
            .navigationTitle("Sleep Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
    }
}

struct StartSessionCard: View {
    var body: some View {
        Button(action: startNewSession) {
            VStack(spacing: 12) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.purple)
                
                Text("Start Sleep Session")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(15)
            .shadow(radius: 2)
        }
    }
    
    private func startNewSession() {
        SleepSessionManager.shared.startSession { _ in }
    }
}

struct Chart: View {
    let sessions: [SleepSession]
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let points = calculatePoints(in: geometry.size)
                if let first = points.first {
                    path.move(to: first)
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(Color.purple, lineWidth: 2)
        }
    }
    
    private func calculatePoints(in size: CGSize) -> [CGPoint] {
        guard !sessions.isEmpty else { return [] }
        
        let points = sessions.compactMap { session -> CGPoint? in
            guard let duration = session.duration else { return nil }
            
            let maxDuration = sessions.compactMap { $0.duration }.max() ?? duration
            let index = CGFloat(sessions.firstIndex(of: session) ?? 0)
            let x = index / CGFloat(sessions.count - 1) * size.width
            let y = size.height - (duration / maxDuration * size.height)
            
            return CGPoint(x: x, y: y)
        }
        
        return points
    }
}

// MARK: - Helper Extensions

extension SleepSession {
    var duration: TimeInterval? {
        guard let startTime = startTime,
              let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
