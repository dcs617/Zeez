import SwiftUI
import Charts
import os.log

struct SleepInformationView: View {
    let session: SleepSession?
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingTips = false
    
    var body: some View {
        ScrollView {
            if let session = session {
                VStack(spacing: 20) {
                    durationSection(session)
                    sleepTimesSection(session)
                    sleepEfficiencySection(session)
                    timeBreakdownSection(session)
                }
                .padding()
            } else {
                noDataView
            }
        }
        .navigationTitle("Sleep Information")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                showingTips = true
            } label: {
                Image(systemName: "info.circle")
            }
            .accessibilityLabel("Sleep information guide")
            .accessibilityHint("Get detailed explanations about sleep metrics and information")
            .accessibilityIdentifier("sleepInfoGuideButton")
        }
        .sheet(isPresented: $showingTips) {
            SleepInfoGuideView()
        }
    }
    
    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
            
            Text("No Sleep Data Available")
                .font(.headline)
            
            Text("Track your sleep to see detailed sleep information and trends.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No sleep data available")
        .accessibilityHint("Track your sleep to see detailed sleep information and trends")
        .accessibilityIdentifier("noSleepInfoDataView")
    }
    
    private func durationSection(_ session: SleepSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recorded Session Duration")
                .font(.headline)
            
            HStack(spacing: 20) {
                CircularProgressView(
                    value: recordedIntervalHours(session),
                    total: 8,
                    lineWidth: 12,
                    size: 120
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    MetricRow(
                        label: "Session Duration",
                        value: formatDuration(session.recordedInterval)
                    )

                    MetricRow(
                        label: "Reference Goal",
                        value: formatDuration(AppConstants.Sleep.targetDuration)
                    )
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recorded session duration section: Session duration \(formatDuration(session.recordedInterval)), reference sleep goal \(formatDuration(AppConstants.Sleep.targetDuration))")
        .accessibilityHint("Shows the recorded session interval alongside your reference sleep goal")
        .accessibilityIdentifier("sleepDurationSection")
    }
    
    private func sleepTimesSection(_ session: SleepSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Times")
                .font(.headline)
            
            VStack(spacing: 16) {
                TimeRow(
                    icon: "moon.fill",
                    label: "Bedtime",
                    time: session.startTime ?? Date()
                )
                
                TimeRow(
                    icon: "sun.max.fill",
                    label: "Wake Time",
                    time: session.endTime ?? Date()
                )
                
                if let startTime = session.startTime,
                   let endTime = session.endTime {
                    TimeRow(
                        icon: "clock.fill",
                        label: "Duration",
                        value: formatDuration(endTime.timeIntervalSince(startTime))
                    )
                }
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    /// Efficiency comes from `DerivedSleepMetrics`, which divides qualified asleep time
    /// by *reported* in-bed time. The recording interval is not an in-bed denominator
    /// (claims rule 6), so sessions without reported `inBed` intervals show unavailable.
    private func sleepEfficiencySection(_ session: SleepSession) -> some View {
        let efficiency = session.derivedSleepMetrics.sleepEfficiency

        return VStack(alignment: .leading, spacing: 12) {
            Text(efficiency.value == nil ? "Recorded Session Duration" : "Derived Sleep Efficiency")
                .font(.headline)

            if let value = efficiency.value {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(value))%")
                            .font(.title)
                            .bold()
                        Text("Time asleep as a percentage of reported time in bed")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Derived from Apple Health records")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    CircularProgressView(value: value, total: 100, lineWidth: 8, size: 60)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Derived sleep efficiency \(Int(value)) percent")
                .accessibilityHint("Time asleep as a percentage of time in bed reported by Apple Health")
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDuration(session.recordedInterval))
                        .font(.title)
                        .bold()
                    Text("Sleep efficiency unavailable")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(efficiencyUnavailableExplanation(session))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Sleep efficiency unavailable. Recorded session duration \(formatDuration(session.recordedInterval))")
                .accessibilityHint(efficiencyUnavailableExplanation(session))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
        .accessibilityIdentifier("sleepEfficiencySection")
    }

    /// Stage composition is a percentage *of staged sleep*: `inBed` and awake rows are
    /// excluded from the denominator (rules 5 and 6), `asleepUnspecified` is preserved
    /// as its own row, and stage names carry their source (rule 1).
    private func timeBreakdownSection(_ session: SleepSession) -> some View {
        let metrics = session.derivedSleepMetrics
        let reportedByAppleHealth = metrics.hasAppleHealthProvenance

        return VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Stage Composition")
                .font(.headline)

            if let composition = metrics.asleepStageComposition.value {
                let stagedTotal = composition.values.reduce(0, +)

                Text(session.stageSourceDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("stageCompositionProvenance")

                VStack(spacing: 16) {
                    ForEach(Self.compositionStageOrder, id: \.self) { stage in
                        if let duration = composition[stage], duration > 0 {
                            TimeBreakdownRow(
                                label: stage.displayName(reportedByAppleHealth: reportedByAppleHealth),
                                duration: duration,
                                total: stagedTotal
                            )
                        }
                    }
                }

                Text("Percentages are of staged sleep (\(formatDuration(stagedTotal))). Time in bed and awake periods are excluded.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Sleep stage composition unavailable")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("This session has no sleep stage intervals Zeez can total.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Awake time is reported alongside the composition, never inside its
            // denominator, and only when Apple Health reported awake intervals.
            if let awake = metrics.recordedAwakeDuration.value {
                Divider()
                HStack {
                    Text("Recorded awake time")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatDuration(awake))
                        .bold()
                }
                Text("Awake intervals reported by Apple Health. Apple Watch may omit awake periods at the start or end of a session, so this is not a complete count of awakenings.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
        .accessibilityIdentifier("stageCompositionSection")
    }

    // MARK: - Helper Functions

    /// Every asleep stage, in presentation order. `awake` is absent by design, and every
    /// other stage must appear here or its time silently vanishes from the breakdown —
    /// which is how `asleepUnspecified` went missing. Pinned by `SleepInformationViewTests`.
    static let compositionStageOrder: [SleepStageType] = [
        .deepSleep, .lightSleep, .rem, .asleepUnspecified
    ]

    private func recordedIntervalHours(_ session: SleepSession) -> Double {
        session.recordedInterval / 3600
    }

    private func efficiencyUnavailableExplanation(_ session: SleepSession) -> String {
        session.derivedSleepMetrics.reportedInBedDuration.value == nil
            ? "Requires time in bed reported by Apple Health."
            : "Requires reported time in bed and time asleep for this session."
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Supporting Views

struct CircularProgressView: View {
    let value: Double
    let total: Double
    let lineWidth: CGFloat
    let size: CGFloat
    
    private var progress: Double {
        min(max(value / total, 0), 1)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.blue.gradient,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
            
            VStack {
                if total == 100 {
                    Text("\(Int(value))%")
                        .font(.title3)
                        .bold()
                } else {
                    Text(String(format: "%.1f", value))
                        .font(.title3)
                        .bold()
                    Text("hrs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}

struct TimeRow: View {
    let icon: String
    let label: String
    var time: Date? = nil
    var value: String? = nil
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(label)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            if let time = time {
                Text(time.formatted(date: .omitted, time: .shortened))
                    .bold()
            } else if let value = value {
                Text(value)
                    .bold()
            }
        }
    }
}

struct TimeBreakdownRow: View {
    let label: String
    let duration: TimeInterval
    let total: TimeInterval
    
    private var percentage: Double {
        guard total > 0 else { return 0 }
        return (duration / total) * 100
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatDuration(duration))
                    .bold()
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(percentage / 100), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            Text("\(Int(percentage))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue("\(formatDuration(duration)), \(Int(percentage)) percent of staged sleep")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

#Preview {
    NavigationView {
        SleepInformationView(session: nil)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
