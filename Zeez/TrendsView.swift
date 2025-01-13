import SwiftUI
import CoreData

/// View for analyzing sleep trends over time
/// Shows weekly and monthly patterns in sleep quality and duration
struct TrendsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var timeRange: SleepTrendRange = .week
    
    private var dateRange: (start: Date, end: Date) {
        let interval = timeRange.dateInterval
        return (interval.start, interval.end)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                timeRangePicker
                
                sleepDurationTrend
                
                sleepQualityTrend
                
                sleepScheduleConsistency
            }
            .padding()
        }
        .navigationTitle("Sleep Trends")
    }
    
    private var timeRangePicker: some View {
        Picker("Time Range", selection: $timeRange) {
            ForEach(SleepTrendRange.allCases) { range in
                Text(range.description).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var sleepDurationTrend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Duration")
                .font(.headline)
            
            TrendChart(
                data: fetchSleepDurations(),
                valueLabel: "Hours",
                color: .blue
            )
            .frame(height: 200)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var sleepQualityTrend: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Quality")
                .font(.headline)
            
            TrendChart(
                data: fetchSleepQualities(),
                valueLabel: "Score",
                color: .purple
            )
            .frame(height: 200)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private var sleepScheduleConsistency: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Schedule")
                .font(.headline)
            
            ScheduleConsistencyChart(data: fetchSleepSchedule())
                .frame(height: 200)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    private func fetchSleepDurations() -> [(date: Date, value: Double)] {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime <= %@ AND isActive == NO",
            dateRange.start as NSDate,
            dateRange.end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: true)]
        
        guard let sessions = try? viewContext.fetch(request) else { return [] }
        
        return sessions.compactMap { session -> (date: Date, value: Double)? in
            guard let start = session.startTime,
                  let end = session.endTime else { return nil }
            return (date: start, value: end.timeIntervalSince(start) / 3600)
        }
    }
    
    private func fetchSleepQualities() -> [(date: Date, value: Double)] {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime <= %@ AND isActive == NO",
            dateRange.start as NSDate,
            dateRange.end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: true)]
        
        guard let sessions = try? viewContext.fetch(request) else { return [] }
        
        return sessions.compactMap { session -> (date: Date, value: Double)? in
            guard let start = session.startTime else { return nil }
            return (date: start, value: session.qualityScore)
        }
    }
    
    private func fetchSleepSchedule() -> [(date: Date, bedtime: Date, wakeTime: Date)] {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime <= %@ AND isActive == NO",
            dateRange.start as NSDate,
            dateRange.end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: true)]
        
        guard let sessions = try? viewContext.fetch(request) else { return [] }
        
        return sessions.compactMap { session -> (date: Date, bedtime: Date, wakeTime: Date)? in
            guard let start = session.startTime,
                  let end = session.endTime else { return nil }
            return (date: start, bedtime: start, wakeTime: end)
        }
    }
}

struct TrendView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            TrendsView()
                .environment(\.managedObjectContext,
                            PersistenceController.preview.container.viewContext)
        }
    }
}