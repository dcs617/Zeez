import SwiftUI
import CoreData
import os.log

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedDate: Date = Date()
    @State private var showCalendarDropdown = false
    @State private var showingDebugMenu = false
    
    @FetchRequest private var recentSessions: FetchedResults<SleepSession>
    
    private var sessionArray: [SleepSession] {
        Array(recentSessions)
    }
    
    init() {
        let calendar = Calendar.current
        let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: Date())!
        let predicate = NSPredicate(format: "isActive == NO AND startTime >= %@", startOfLastMonth as NSDate)
        _recentSessions = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: false)],
            predicate: predicate,
            animation: .default
        )
    }
    
    private var dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()
    
    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()
    
    var body: some View {
        ZStack(alignment: .top) {
            // Background gradient
            LinearGradient(
                colors: [Color(UIColor.systemBackground), Color(UIColor.secondarySystemBackground).opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.bottom, 8)
                    
                    VStack(spacing: 24) {
                        weeklyProgressSection
                        metricsSection
                        infoCardsSection
                        learningSectionCards
                        
                        if let firstSession = sessionArray.first {
                            RecentSleepBanner(session: firstSession)
                                .padding(.top, 8)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Recent Sleep Session")
                                .accessibilityHint("Shows summary information about your most recent sleep session")
                                .accessibilityIdentifier("recentSleepBanner")
                        }
                        
                        #if DEBUG
                        debugButton
                            .padding(.top, 8)
                        #endif
                    }
                    .padding(.horizontal, 16)
                }
                .frame(maxWidth: 400)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 20)
            }
            .gesture(showCalendarDropdown ? nil : DragGesture())
            
            if showCalendarDropdown {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showCalendarDropdown = false
                        }
                    }
                    .accessibilityLabel("Calendar overlay")
                    .accessibilityHint("Tap to close calendar picker")
                    .accessibilityIdentifier("calendarOverlayDismiss")
                
                calendarOverlay
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .sheet(isPresented: $showingDebugMenu) {
            DebugMenuView(viewContext: viewContext)
        }
    }
    
    private var headerSection: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showCalendarDropdown.toggle()
                }
            }) {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(UIColor.tertiarySystemFill))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Calendar")
            .accessibilityHint(showCalendarDropdown ? "Close calendar picker" : "Open calendar to select a date")
            .accessibilityIdentifier("calendarButton")
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(dayFormatter.string(from: selectedDate))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(dateFormatter.string(from: selectedDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Selected date: \(dayFormatter.string(from: selectedDate)), \(dateFormatter.string(from: selectedDate))")
            .accessibilityIdentifier("selectedDateDisplay")
            
            Spacer()
            
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(UIColor.tertiarySystemFill))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Settings")
            .accessibilityHint("Open app settings and preferences")
            .accessibilityIdentifier("settingsButton")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }
    
    private var weeklyProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weekly Progress")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer(minLength: 0)
                NavigationLink(destination: LearnSleepDebtView()) {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.pie")
                            .font(.caption)
                        Text("View Sleep Debt")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .lineLimit(1)
                }
                .accessibilityLabel("View Sleep Debt")
                .accessibilityHint("Learn about your accumulated sleep debt and how to recover")
                .accessibilityIdentifier("viewSleepDebtLink")
            }
            
            WeeklyProgressView(sessions: sessionArray, selectedDate: $selectedDate)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(16)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Weekly Sleep Progress Chart")
                .accessibilityHint("Shows your sleep duration for each day of the week")
        }
        .frame(maxWidth: .infinity)
    }
    
    private var metricsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Sleep Metrics")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                NavigationLink(destination: LearnCircadianRhythmView()) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("View Patterns")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                .accessibilityLabel("View Sleep Patterns")
                .accessibilityHint("Learn about your circadian rhythm and sleep timing patterns")
                .accessibilityIdentifier("viewPatternsLink")
            }
            
            GeometryReader { geometry in
                let availableWidth = geometry.size.width
                let spacing: CGFloat = 16
                let cardWidth = (availableWidth - spacing) / 2
                
                HStack(spacing: spacing) {
                    SleepAverageCard(sessions: Array(sessionArray.prefix(7)))
                        .frame(width: cardWidth, height: cardWidth)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Sleep Average Card")
                        .accessibilityHint("Shows your average sleep duration for the past 7 days")
                        .accessibilityIdentifier("sleepAverageCard")
                    
                    QualityScoreCard(session: selectedDaySession)
                        .frame(width: cardWidth, height: cardWidth)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Sleep Quality Score Card")
                        .accessibilityHint("Shows your sleep quality score for the selected day")
                        .accessibilityIdentifier("qualityScoreCard")
                }
            }
            .frame(height: ((UIScreen.main.bounds.width - 48) / 2))
        }
        .frame(maxWidth: .infinity)
    }
    
    private var infoCardsSection: some View {
        VStack(spacing: 12) {
            ForEach(SleepCardType.allCases, id: \.self) { cardType in
                cardType.makeCard(session: selectedDaySession)
                    .frame(maxWidth: .infinity)
                    .frame(height: 84)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var learningSectionCards: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Learn & Explore")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(LearningTopic.allCases, id: \.self) { topic in
                        NavigationLink(destination: topic.destination) {
                            LearningCard(
                                title: topic.title,
                                icon: topic.icon,
                                color: topic.color,
                                description: topic.description
                            )
                        }
                        .accessibilityLabel("Learn about \(topic.title)")
                        .accessibilityHint(topic.description)
                        .accessibilityIdentifier("learningCard_\(topic.title.replacingOccurrences(of: " ", with: ""))")
                    }
                }
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
    }
    
    private var selectedDaySession: SleepSession? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = NSPredicate(format: "startTime >= %@ AND startTime < %@ AND isActive == NO",
                                  startOfDay as NSDate,
                                  endOfDay as NSDate)
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = predicate
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: false)]
        
        return try? viewContext.fetch(request).first
    }
    
    private var calendarOverlay: some View {
        VStack(alignment: .leading) {
            CalendarDropdownView(
                selectedDate: $selectedDate,
                isShowing: $showCalendarDropdown,
                sessions: sessionArray
            ) { date in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedDate = date
                }
            }
            Spacer()
        }
        .padding(.top, 80)
        .padding(.horizontal)
        .transition(.asymmetric(
            insertion: .scale.combined(with: .opacity),
            removal: .scale.combined(with: .opacity)
        ))
    }
    
    #if DEBUG
    private var debugButton: some View {
        Button(action: {
            showingDebugMenu = true
        }) {
            HStack {
                Image(systemName: "ladybug.fill")
                Text("Debug Menu")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .accessibilityLabel("Debug Menu")
        .accessibilityHint("Opens development tools for generating test data and clearing app data")
        .accessibilityIdentifier("debugMenuButton")
    }
    #endif
}

// MARK: - Supporting Types
private struct LearningCard: View {
    let title: String
    let icon: String
    let color: Color
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(color)
                    .cornerRadius(12)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(width: 220, height: 120)
        .padding(16)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

private enum LearningTopic: CaseIterable {
    case environment
    case sleepStages
    case sleepRhythm
    
    var title: String {
        switch self {
        case .environment: return "Environment"
        case .sleepStages: return "Sleep Stages"
        case .sleepRhythm: return "Sleep Rhythm"
        }
    }
    
    var icon: String {
        switch self {
        case .environment: return "thermometer.sun"
        case .sleepStages: return "chart.bar.doc.horizontal"
        case .sleepRhythm: return "clock"
        }
    }
    
    var color: Color {
        switch self {
        case .environment: return .green
        case .sleepStages: return .blue
        case .sleepRhythm: return .orange
        }
    }
    
    var description: String {
        switch self {
        case .environment: return "How your surroundings affect sleep"
        case .sleepStages: return "Understanding sleep cycles"
        case .sleepRhythm: return "Your natural sleep patterns"
        }
    }
    
    @ViewBuilder
    var destination: some View {
        switch self {
        case .environment: LearnEnvironmentalImpactView()
        case .sleepStages: LearnSleepStageComparisonView()
        case .sleepRhythm: LearnCircadianRhythmView()
        }
    }
}

private enum SleepCardType: CaseIterable {
    case quality
    case heartRate
    case information
    case cycles
    
    @ViewBuilder
    func makeCard(session: SleepSession?) -> some View {
        switch self {
        case .quality:
            NavigationLink(destination: SleepQualityView(session: session)) {
                SummaryCard(
                    icon: "chart.bar.fill",
                    title: "Sleep Quality",
                    hasData: session != nil,
                    session: session,
                    previewStat: session.flatMap(SleepQualityPreviewStats.getRandomStat)
                )
            }
            .accessibilityLabel("Sleep Quality")
            .accessibilityHint("View detailed sleep quality analysis and metrics")
            .accessibilityIdentifier("sleepQualityCard")
        case .heartRate:
            NavigationLink(destination: HeartRateView(session: session)) {
                SummaryCard(
                    icon: "heart.fill",
                    title: "Heart Rate",
                    hasData: session?.heartRateData?.count ?? 0 > 0,
                    session: session,
                    previewStat: session.flatMap(HeartRatePreviewStats.getRandomStat)
                )
            }
            .accessibilityLabel("Heart Rate")
            .accessibilityHint("View heart rate data and trends during sleep")
            .accessibilityIdentifier("heartRateCard")
        case .information:
            NavigationLink(destination: SleepInformationView(session: session)) {
                SummaryCard(
                    icon: "moon.zzz.fill",
                    title: "Sleep Information",
                    hasData: session != nil,
                    session: session,
                    previewStat: session.flatMap(SleepInfoPreviewStats.getRandomStat)
                )
            }
            .accessibilityLabel("Sleep Information")
            .accessibilityHint("View comprehensive sleep session details and statistics")
            .accessibilityIdentifier("sleepInfoCard")
        case .cycles:
            NavigationLink(destination: SleepCyclesView(session: session)) {
                SummaryCard(
                    icon: "waveform.path.ecg",
                    title: "Sleep Cycles",
                    hasData: session?.sleepStages?.count ?? 0 > 0,
                    session: session,
                    previewStat: session.flatMap(SleepCyclesPreviewStats.getRandomStat)
                )
            }
            .accessibilityLabel("Sleep Cycles")
            .accessibilityHint("View sleep stages and cycle analysis")
            .accessibilityIdentifier("sleepCyclesCard")
        }
    }
}

#if DEBUG
struct DebugMenuView: View {
    let viewContext: NSManagedObjectContext
    @Environment(\.dismiss) private var dismiss
    @State private var isGeneratingData = false
    @State private var selectedDays = 90
    
    var body: some View {
        NavigationView {
            List {
                Section("Mock Data") {
                    Picker("Days of Data", selection: $selectedDays) {
                        Text("30 Days").tag(30)
                        Text("90 Days").tag(90)
                        Text("180 Days").tag(180)
                    }
                    .accessibilityLabel("Days of mock data to generate")
                    .accessibilityHint("Select how many days of test sleep data to create")
                    
                    Button(action: generateMockData) {
                        if isGeneratingData {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("Generate New Mock Data")
                        }
                    }
                    .disabled(isGeneratingData)
                    .accessibilityLabel(isGeneratingData ? "Generating mock data" : "Generate new mock data")
                    .accessibilityHint("Creates sample sleep tracking data for testing the app")
                    .accessibilityIdentifier("generateMockDataButton")
                }
                
                Section("Data Management") {
                    Button(role: .destructive, action: clearAllData) {
                        Text("Clear All Data")
                    }
                    .accessibilityLabel("Clear all data")
                    .accessibilityHint("Warning: This permanently deletes all sleep tracking data")
                    .accessibilityIdentifier("clearAllDataButton")
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarItems(trailing: 
                Button("Done") { dismiss() }
                    .accessibilityLabel("Done")
                    .accessibilityHint("Close debug menu")
                    .accessibilityIdentifier("debugMenuDoneButton")
            )
        }
    }
    
    private func generateMockData() {
        isGeneratingData = true
        clearAllData()
        MockDataGenerator.shared.generateMockData(for: selectedDays)
        defer { isGeneratingData = false }
        
        do {
            try viewContext.save()
        } catch {
            ZeezLogger.error(ZeezLogger.ui, "Failed to save context after generating mock data", error: error)
        }
    }
    
    private func clearAllData() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = SleepSession.fetchRequest()
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try viewContext.execute(batchDeleteRequest)
            try viewContext.save()
        } catch {
            ZeezLogger.error(ZeezLogger.ui, "Failed to clear data", error: error)
        }
    }
}
#endif

#Preview {
    NavigationView {
        DashboardView()
            .environment(\.managedObjectContext, createPreviewContext())
    }
}

private func createPreviewContext() -> NSManagedObjectContext {
    let context = PersistenceController.preview.container.viewContext
    MockDataGenerator.shared.generateMockData(for: AppConstants.MockData.debugGenerationDays)
    return context
}
