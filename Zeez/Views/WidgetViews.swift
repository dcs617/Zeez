import SwiftUI
import CoreData
import os.log

struct SleepQualityWidget: View {
    @Environment(\.managedObjectContext) private var viewContext
    let date: Date
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Sleep Quality", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("sleepQualityWidgetHeader")
                Spacer()
            }
            
            if let session = fetchSession() {
                QualityScoreCard(session: session)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Sleep quality score for \(date.formatted(date: .abbreviated, time: .omitted))")
                    .accessibilityIdentifier("qualityScoreCard")
            } else {
                Text("No data for selected date")
                    .foregroundColor(.gray)
                    .accessibilityLabel("No sleep quality data available for \(date.formatted(date: .abbreviated, time: .omitted))")
                    .accessibilityIdentifier("noQualityData")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sleepQualityWidget")
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
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("heartRateWidgetHeader")
                Spacer()
            }
            
            if let session = fetchSession(),
               let heartRateData = session.heartRateData?.allObjects as? [HeartRateData],
               !heartRateData.isEmpty {
                
                let minRate = Int(heartRateData.min { $0.value < $1.value }?.value ?? 0)
                let avgRate = Int(heartRateData.reduce(0) { $0 + $1.value } / Double(heartRateData.count))
                let maxRate = Int(heartRateData.max { $0.value < $1.value }?.value ?? 0)
                
                HStack(spacing: 20) {
                    StatBox(
                        title: "Min",
                        value: "\(minRate)",
                        unit: "bpm"
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Minimum heart rate: \(minRate) beats per minute")
                    .accessibilityIdentifier("minHeartRateStat")
                    
                    StatBox(
                        title: "Avg",
                        value: "\(avgRate)",
                        unit: "bpm"
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Average heart rate: \(avgRate) beats per minute")
                    .accessibilityIdentifier("avgHeartRateStat")
                    
                    StatBox(
                        title: "Max",
                        value: "\(maxRate)",
                        unit: "bpm"
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Maximum heart rate: \(maxRate) beats per minute")
                    .accessibilityIdentifier("maxHeartRateStat")
                }
            } else {
                Text("No data for selected date")
                    .foregroundColor(.gray)
                    .accessibilityLabel("No heart rate data available for \(date.formatted(date: .abbreviated, time: .omitted))")
                    .accessibilityIdentifier("noHeartRateData")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("heartRateWidget")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) \(unit)")
        .accessibilityIdentifier("statBox_\(title.lowercased())")
    }
}

// Placeholder views for premium widgets - they will be wrapped in PremiumWidgetPlaceholder by WidgetContainer when needed
struct SleepDebtWidget: View {
    let date: Date
    
    var body: some View {
        Text("Sleep Debt Widget Content")
            .accessibilityLabel("Sleep debt widget content for \(date.formatted(date: .abbreviated, time: .omitted))")
            .accessibilityIdentifier("sleepDebtWidget")
    }
}

struct EnvironmentWidget: View {
    let date: Date
    
    var body: some View {
        Text("Environment Widget Content")
            .accessibilityLabel("Environmental conditions widget for \(date.formatted(date: .abbreviated, time: .omitted))")
            .accessibilityIdentifier("environmentWidget")
    }
}

struct SleepGoalsWidget: View {
    let date: Date
    
    var body: some View {
        Text("Sleep Goals Widget Content")
            .accessibilityLabel("Sleep goals widget for \(date.formatted(date: .abbreviated, time: .omitted))")
            .accessibilityIdentifier("sleepGoalsWidget")
    }
}

struct MonthlyTrendWidget: View {
    let date: Date
    
    var body: some View {
        Text("Monthly Trend Widget Content")
            .accessibilityLabel("Monthly trend widget for \(date.formatted(date: .abbreviated, time: .omitted))")
            .accessibilityIdentifier("monthlyTrendWidget")
    }
}


