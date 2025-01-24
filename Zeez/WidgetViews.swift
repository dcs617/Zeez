import SwiftUI
import CoreData

struct SleepQualityWidget: View {
    @Environment(\.managedObjectContext) private var viewContext
    let date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Sleep Quality", systemImage: "chart.bar.fill")
                    .font(.headline)
                Spacer()
            }
            
            if let session = fetchSession() {
                QualityScoreCard(session: session)
            } else {
                Text("No data for selected date")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func fetchSession() -> SleepSession? {
        let request = NSFetchRequest<SleepSession>(entityName: "SleepSession")
        request.predicate = NSPredicate(format: "startTime >= %@ AND startTime < %@",
                                      Calendar.current.startOfDay(for: date) as NSDate,
                                      Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: date)!) as NSDate)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }
}

struct HeartRateWidget: View {
    @Environment(\.managedObjectContext) private var viewContext
    let date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Heart Rate", systemImage: "heart.fill")
                    .font(.headline)
                Spacer()
            }
            
            if let session = fetchSession(),
               let heartRateData = session.heartRateData?.allObjects as? [HeartRateData],
               !heartRateData.isEmpty {
                
                HStack(spacing: 20) {
                    StatBox(
                        title: "Min",
                        value: "\(Int(heartRateData.min { $0.value < $1.value }?.value ?? 0))",
                        unit: "bpm"
                    )
                    
                    StatBox(
                        title: "Avg",
                        value: "\(Int(heartRateData.reduce(0) { $0 + $1.value } / Double(heartRateData.count)))",
                        unit: "bpm"
                    )
                    
                    StatBox(
                        title: "Max",
                        value: "\(Int(heartRateData.max { $0.value < $1.value }?.value ?? 0))",
                        unit: "bpm"
                    )
                }
            } else {
                Text("No data for selected date")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func fetchSession() -> SleepSession? {
        let request = NSFetchRequest<SleepSession>(entityName: "SleepSession")
        request.predicate = NSPredicate(format: "startTime >= %@ AND startTime < %@",
                                      Calendar.current.startOfDay(for: date) as NSDate,
                                      Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: date)!) as NSDate)
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .bold()
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

// Placeholder views for premium widgets - they will be wrapped in PremiumWidgetPlaceholder by WidgetContainer when needed
struct SleepDebtWidget: View {
    let date: Date
    
    var body: some View {
        Text("Sleep Debt Widget Content")
    }
}

struct EnvironmentWidget: View {
    let date: Date
    
    var body: some View {
        Text("Environment Widget Content")
    }
}

struct SleepGoalsWidget: View {
    let date: Date
    
    var body: some View {
        Text("Sleep Goals Widget Content")
    }
}

struct MonthlyTrendWidget: View {
    let date: Date
    
    var body: some View {
        Text("Monthly Trend Widget Content")
    }
}


