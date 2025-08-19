import SwiftUI
import CoreData
import os.log

struct WidgetContainer: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showWidget = false
    @State private var selectedWidget: WidgetType = .sleepQuality
    @State private var showingRecommendations = false
    @State private var selectedDate = Date()
    
    @FetchRequest(
        entity: UserPreferences.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \UserPreferences.createdAt, ascending: true)]
    ) private var preferences: FetchedResults<UserPreferences>
    
    private var preferencesArray: [UserPreferences] {
        Array(preferences)
    }
    
    private let widgetTypes: [WidgetType] = [
        .sleepQuality,
        .heartRate,
        .sleepDebt,
        .environment,
        .sleepGoals,
        .monthlyTrend
    ]
    
    var body: some View {
        VStack(alignment: .leading) {
            if showWidget {
                VStack {
                    widgetHeader
                    
                    widgetPicker
                    
                    getWidget(for: selectedWidget)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    
                    if let prefs = preferencesArray.first {
                        getInfoView(for: selectedWidget, preferences: prefs)
                    }
                }
                .padding(.vertical)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                Button(action: { showWidget = true }) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut, value: showWidget)
    }
    
    private var widgetHeader: some View {
        HStack {
            Text("Widget")
                .font(.headline)
            
            Spacer()
            
            Button(action: { showWidget = false }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }
    
    private var widgetPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(widgetTypes, id: \.rawValue) { type in
                    widgetButton(type)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private func widgetButton(_ type: WidgetType) -> some View {
        Button(action: { selectedWidget = type }) {
            HStack {
                Image(systemName: type.systemImage)
                Text(type.rawValue)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(selectedWidget == type ? Color.blue : Color(.systemGray5))
            )
            .foregroundColor(selectedWidget == type ? .white : .primary)
        }
    }
    
    @ViewBuilder
    private func getWidget(for type: WidgetType) -> some View {
        if preferencesArray.first != nil {
            switch type {
            case .sleepQuality:
                if let latestSession = fetchLatestSession() {
                    SleepQualityView(session: latestSession)
                }
            case .heartRate:
                if let latestSession = fetchLatestSession() {
                    HeartRateView(session: latestSession)
                }
            case .sleepDebt:
                let metrics = SleepDebtMetrics(
                    weeklyDebt: SleepDebtCalculator.shared.calculateCurrentDebt(context: viewContext),
                    monthlyDebt: SleepDebtCalculator.shared.calculateCurrentDebt(context: viewContext),
                    debtTrend: .stable,
                    recoveryPlan: RecoveryPlan(
                        recommendedAction: "Get extra sleep tonight",
                        timeToRecover: "2 days",
                        severity: .moderate
                    )
                )
                SleepDebtSection(metrics: metrics, showingRecommendations: $showingRecommendations)
            case .environment:
                EnvironmentMetricView(
                    icon: "thermometer",
                    label: "Room Temperature",
                    value: "20°C",
                    rating: "Optimal"
                )
            case .sleepGoals:
                let weekSessions = fetchWeekSessions()
                WeeklyProgressView(
                    sessions: weekSessions,
                    selectedDate: $selectedDate
                )
            case .monthlyTrend:
                MonthlyTrendsView()
            }
        } else {
            Text("Loading...")
                .foregroundColor(.secondary)
        }
    }
    
    private func getInfoView(for type: WidgetType, preferences: UserPreferences) -> some View {
        Text(getWidgetDescription(for: type))
            .padding(.horizontal)
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    private func getWidgetDescription(for type: WidgetType) -> String {
        switch type {
        case .sleepQuality:
            return "Shows your sleep quality score based on various metrics."
        case .heartRate:
            return "Displays your heart rate patterns during sleep."
        case .sleepDebt:
            return "Tracks your accumulated sleep debt and recovery status."
        case .environment:
            return "Monitors your sleep environment conditions."
        case .sleepGoals:
            return "Shows progress towards your sleep goals."
        case .monthlyTrend:
            return "Visualizes your sleep patterns over the month."
        }
    }
    
    private func fetchLatestSession() -> SleepSession? {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: false)]
        request.fetchLimit = 1
        return try? viewContext.fetch(request).first
    }
    
    private func fetchWeekSessions() -> [SleepSession] {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: true)]
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime <= %@",
            Calendar.current.date(byAdding: .day, value: -7, to: Date())! as NSDate,
            Date() as NSDate
        )
        return (try? viewContext.fetch(request)) ?? []
    }
}

#Preview {
    WidgetContainer()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
