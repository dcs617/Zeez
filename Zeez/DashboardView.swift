import SwiftUI
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedDate: Date = Date()
    @State private var showCalendarDropdown = false
    @State private var showingDebugMenu = false
    
    @FetchRequest<SleepSession>(
        sortDescriptors: [NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: false)],
        predicate: NSPredicate(format: "isActive == NO"),
        animation: .default
    ) private var recentSessions
    
    private var sessionArray: [SleepSession] {
        Array(recentSessions)
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
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Color(UIColor.systemBackground)
                    .frame(height: 4)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        headerSection
                        weeklyProgress
                        metricsSection
                        infoCardsSection
                        learningSectionCards
                        
                        if let firstSession = sessionArray.first {
                            RecentSleepBanner(session: firstSession)
                                .padding(.horizontal)
                        }
                        
                        #if DEBUG
                        debugButton
                        #endif
                    }
                }
                .background(Color(UIColor.systemBackground))
            }
            
            if showCalendarDropdown {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            showCalendarDropdown = false
                        }
                    }
                
                calendarOverlay
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingDebugMenu) {
            DebugMenuView(viewContext: viewContext)
        }
    }
    
    private var headerSection: some View {
        HStack(spacing: 20) {
            Button(action: {
                withAnimation {
                    showCalendarDropdown.toggle()
                }
            }) {
                Image(systemName: "calendar")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Text(dayFormatter.string(from: selectedDate))
                    .font(.title2)
                    .fontWeight(.bold)
                Text(dateFormatter.string(from: selectedDate))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            NavigationLink(destination: SettingsView()) {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var calendarOverlay: some View {
        VStack(alignment: .leading) {
            CalendarDropdownView(
                selectedDate: $selectedDate,
                isShowing: $showCalendarDropdown,
                sessions: sessionArray
            ) { date in
                withAnimation {
                    selectedDate = date
                }
            }
            Spacer()
        }
        .padding(.top, 100)
        .padding(.horizontal)
        .transition(.scale)
    }
    
    private var weeklyProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Weekly Progress")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: LearnSleepDebtView()) {
                    Label("View Sleep Debt", systemImage: "chart.pie")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            WeeklyProgressView(sessions: sessionArray, selectedDate: $selectedDate)
        }
        .padding(.horizontal)
    }
    
    private var metricsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Sleep Metrics")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: LearnCircadianRhythmView()) {
                    Label("Learn Sleep Patterns", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            HStack(spacing: 16) {
                SleepAverageCard(sessions: Array(sessionArray.prefix(7)))
                    .frame(maxWidth: .infinity)
                
                QualityScoreCard(session: selectedDaySession)
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 150)
        }
        .padding(.horizontal)
    }
    
    private var infoCardsSection: some View {
        VStack(spacing: 12) {
            NavigationLink(destination: SleepQualityView(session: selectedDaySession)) {
                SummaryCard(
                    icon: "chart.bar.fill",
                    title: "Sleep Quality",
                    hasData: selectedDaySession != nil,
                    session: selectedDaySession,
                    previewStat: selectedDaySession.flatMap(SleepQualityPreviewStats.getRandomStat),
                    educationalLink: AnyView(
                        NavigationLink(destination: LearnSleepStageComparisonView()) {
                            Label("Compare Sleep Stages", systemImage: "arrow.left.arrow.right")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    )
                )
            }
            
            NavigationLink(destination: HeartRateView(session: selectedDaySession)) {
                SummaryCard(
                    icon: "heart.fill",
                    title: "Heart Rate",
                    hasData: selectedDaySession?.heartRateData?.count ?? 0 > 0,
                    session: selectedDaySession,
                    previewStat: selectedDaySession.flatMap(HeartRatePreviewStats.getRandomStat),
                    educationalLink: AnyView(
                        NavigationLink(destination: LearnBrainActivityVisualizer()) {
                            Label("View Brain Activity", systemImage: "brain.head.profile")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    )
                )
            }
            
            NavigationLink(destination: SleepInformationView(session: selectedDaySession)) {
                SummaryCard(
                    icon: "moon.zzz.fill",
                    title: "Sleep Information",
                    hasData: selectedDaySession != nil,
                    session: selectedDaySession,
                    previewStat: selectedDaySession.flatMap(SleepInfoPreviewStats.getRandomStat)
                )
            }
            
            NavigationLink(destination: SleepCyclesView(session: selectedDaySession)) {
                SummaryCard(
                    icon: "waveform.path.ecg",
                    title: "Sleep Cycles",
                    hasData: selectedDaySession?.sleepStages?.count ?? 0 > 0,
                    session: selectedDaySession,
                    previewStat: selectedDaySession.flatMap(SleepCyclesPreviewStats.getRandomStat)
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var learningSectionCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Learn & Explore")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    NavigationLink(destination: LearnEnvironmentalImpactView()) {
                        LearningCard(
                            title: "Environment",
                            icon: "thermometer.sun",
                            color: .green,
                            description: "How your surroundings affect sleep"
                        )
                    }
                    
                    NavigationLink(destination: LearnSleepStageComparisonView()) {
                        LearningCard(
                            title: "Sleep Stages",
                            icon: "chart.bar.doc.horizontal",
                            color: .blue,
                            description: "Understanding sleep cycles"
                        )
                    }
                    
                    NavigationLink(destination: LearnCircadianRhythmView()) {
                        LearningCard(
                            title: "Sleep Rhythm",
                            icon: "clock",
                            color: .orange,
                            description: "Your natural sleep patterns"
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var selectedDaySession: SleepSession? {
        sessionArray.first { session in
            guard let startTime = session.startTime else { return false }
            return Calendar.current.isDate(startTime, inSameDayAs: selectedDate)
        }
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
        .padding(.horizontal)
    }
    #endif
}

struct LearningCard: View {
    let title: String
    let icon: String
    let color: Color
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.headline)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(width: 160)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
                    
                    Button(action: generateMockData) {
                        if isGeneratingData {
                            ProgressView()
                                .progressViewStyle(.circular)
                        } else {
                            Text("Generate New Mock Data")
                        }
                    }
                    .disabled(isGeneratingData)
                }
                
                Section("Data Management") {
                    Button(role: .destructive, action: clearAllData) {
                        Text("Clear All Data")
                    }
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
    
    private func generateMockData() {
        isGeneratingData = true
        
        // Clear existing data first
        clearAllData()
        
        // Generate new data
        MockDataGenerator.shared.generateMockData(for: selectedDays)
        
        defer { isGeneratingData = false }
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save context after generating mock data: \(error)")
        }
    }
    
    private func clearAllData() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = SleepSession.fetchRequest()
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        
        do {
            try viewContext.execute(batchDeleteRequest)
            try viewContext.save()
        } catch {
            print("Failed to clear data: \(error)")
        }
    }
}
#endif

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            DashboardView()
                .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        }
    }
}
