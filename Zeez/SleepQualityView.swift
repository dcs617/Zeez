import SwiftUI
import Charts

struct SleepQualityView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var trendData: [TrendPoint] = []
    @State private var selectedDate: Date?
    @State private var showingTips = false
    
    let session: SleepSession?
    
    private struct TrendPoint: Identifiable {
        let id = UUID()
        let date: Date
        let score: Double
    }
    
    var body: some View {
        ScrollView {
            if let session = session {
                LazyVStack(spacing: 20) {
                    overallScoreSection(session)
                    qualityTrendSection
                    metricsSection(session)
                    stagesSection(session)
                    environmentSection(session)
                }
                .padding()
            } else {
                noDataView
            }
        }
        .navigationTitle("Sleep Quality")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                showingTips = true
            } label: {
                Image(systemName: "questionmark.circle")
            }
        }
        .sheet(isPresented: $showingTips) {
            SleepQualityTipsView()
        }
        .task {
            loadTrendData()
        }
    }
    
    private func overallScoreSection(_ session: SleepSession) -> some View {
        VStack(spacing: 16) {
            QualityScoreRing(
                score: session.qualityScore,
                size: 160,
                lineWidth: 12
            )
            
            Text("Overall Sleep Quality")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private var qualityTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quality Trend")
                .font(.headline)
            
            if trendData.isEmpty {
                Text("No trend data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Chart {
                    ForEach(trendData) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Score", point.score)
                        )
                        .foregroundStyle(Color.blue.gradient)
                        
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Score", point.score)
                        )
                        .foregroundStyle(Color.blue.opacity(0.1))
                        
                        if let selected = selectedDate,
                           Calendar.current.isDate(point.date, inSameDayAs: selected) {
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Score", point.score)
                            )
                            .foregroundStyle(.blue)
                            .annotation {
                                Text("\(Int(point.score))%")
                                    .font(.caption)
                                    .padding(6)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        if let date = value.as(Date.self) {
                            AxisGridLine()
                            AxisValueLabel {
                                Text(date.formatted(.dateTime.weekday(.short)))
                                    .font(.caption)
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let x = value.location.x
                                        if let date: Date = proxy.value(atX: x) {
                                            selectedDate = date
                                        }
                                    }
                            )
                    }
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private func metricsSection(_ session: SleepSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quality Metrics")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                let metrics = calculateMetrics(session)
                
                MetricCard(
                    title: "Sleep Duration",
                    score: metrics.duration,
                    icon: "clock.fill",
                    description: "Sleep duration relative to your target"
                )
                
                MetricCard(
                    title: "Sleep Cycles",
                    score: metrics.cycles,
                    icon: "waveform.path.ecg",
                    description: "Quality of your sleep cycle progression"
                )
                
                MetricCard(
                    title: "Sleep Consistency",
                    score: metrics.consistency,
                    icon: "calendar",
                    description: "Consistency of your sleep schedule"
                )
                
                MetricCard(
                    title: "Environment",
                    score: session.environmentalScore,
                    icon: "thermometer",
                    description: "Quality of your sleep environment"
                )
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private func stagesSection(_ session: SleepSession) -> some View {
        Group {
            if let stages = session.sleepStages?.allObjects as? [SleepStage],
               !stages.isEmpty {
                SleepStageBreakdown(stages: stages)
            }
        }
    }
    
    private func environmentSection(_ session: SleepSession) -> some View {
        Group {
            if let readings = session.environmentalReadings?.allObjects as? [EnvironmentalReading],
               !readings.isEmpty {
                EnvironmentalFactors(readings: readings)
            }
        }
    }
    
    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
            
            Text("No Sleep Data Available")
                .font(.headline)
            
            Text("Start tracking your sleep to see quality metrics and insights.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func loadTrendData() {
        guard let session = session,
              let sessionDate = session.startTime else { return }
        
        let calendar = Calendar.current
        let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: sessionDate)
        ) ?? sessionDate
        
        let request = SleepSession.fetchRequest()
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime < %@ AND isActive == NO",
            weekStart as NSDate,
            calendar.date(byAdding: .day, value: 7, to: weekStart)! as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SleepSession.startTime, ascending: true)]
        
        if let sessions = try? viewContext.fetch(request) {
            trendData = sessions.compactMap { session in
                guard let date = session.startTime else { return nil }
                return TrendPoint(date: date, score: session.qualityScore)
            }
            
            if let sessionStart = session.startTime {
                selectedDate = calendar.startOfDay(for: sessionStart)
            }
        }
    }
    
    private func calculateMetrics(_ session: SleepSession) -> (duration: Double, cycles: Double, consistency: Double) {
        let calculator = SleepQualityCalculator(session: session, context: viewContext)
        let metrics = calculator.calculateMetrics()
        return (metrics.durationScore, metrics.cycleScore, metrics.consistencyScore)
    }
}

private struct MetricCard: View {
    let title: String
    let score: Double
    let icon: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(scoreColor)
                
                Text(title)
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(score))%")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(scoreColor)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(scoreColor)
                        .frame(width: geometry.size.width * CGFloat(score / 100), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
        }
    }
    
    private var scoreColor: Color {
        switch score {
        case 90...: return .green
        case 70..<90: return .blue
        case 50..<70: return .yellow
        default: return .red
        }
    }
}

#Preview {
    NavigationView {
        SleepQualityView(session: nil)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}