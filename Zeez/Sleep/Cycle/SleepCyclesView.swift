import SwiftUI
import os.log

struct SleepCyclesView: View {
    let session: SleepSession?
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingInfo = false
    
    var body: some View {
        ScrollView {
            if let session = session {
                VStack(spacing: 20) {
                    sleepTimingCard(session)
                    
                    NavigationLink(destination: LearnCircadianRhythmView()) {
                        CircadianInfoCard()
                    }
                    
                    sleepStagesCard(session)
                    cycleAnalysisCard(session)
                    stageDistributionCard(session)
                    
                    NavigationLink(destination: LearnSleepStageComparisonView()) {
                        CompareStagesCard()
                    }
                }
                .padding()
            } else {
                noDataView
            }
        }
        .navigationTitle("Sleep Cycles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingInfo = true
                } label: {
                    Image(systemName: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showingInfo) {
            SleepCycleInfoView()
        }
    }
    
    private var noDataView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 44))
                .foregroundStyle(.blue)
            
            Text("No Sleep Data Available")
                .font(.headline)
            
            Text("Track your sleep to see your sleep cycle patterns.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            NavigationLink(destination: LearnSleepStageComparisonView()) {
                Text("Learn About Sleep Stages")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func sleepTimingCard(_ session: SleepSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sleep Time")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink(destination: LearnCircadianRhythmView()) {
                    Label("Sleep Timing", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            HStack {
                if let startTime = session.startTime {
                    VStack(alignment: .leading) {
                        Text("Bedtime")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(startTime.formatted(date: .omitted, time: .shortened))
                            .font(.title2)
                            .bold()
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let endTime = session.endTime {
                    VStack(alignment: .trailing) {
                        Text("Wake Time")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(endTime.formatted(date: .omitted, time: .shortened))
                            .font(.title2)
                            .bold()
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private func sleepStagesCard(_ session: SleepSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sleep Stages")
                    .font(.headline)
                
                Spacer()
                
                NavigationLink(destination: LearnSleepStageComparisonView()) {
                    Label("Compare Stages", systemImage: "arrow.left.arrow.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if let stages = sortedStages(session) {
                VStack(spacing: 12) {
                    SleepStagesTimeline(stages: stages)
                        .frame(height: 60)
                    
                    HStack {
                        ForEach([
                            ("Awake", Color.gray),
                            ("Light Sleep", .blue),
                            ("Deep Sleep", .purple),
                            ("REM Sleep", .pink)
                        ], id: \.0) { stage, color in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(color)
                                    .frame(width: 8, height: 8)
                                Text(stage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                Text("No sleep stage data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private func cycleAnalysisCard(_ session: SleepSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cycle Analysis")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(.blue)
                    
                    Text("Overall Quality")
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(session.qualityScore))%")
                        .bold()
                }
                
                Text("Based on cycle completion and consistency")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                            .cornerRadius(3)
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * CGFloat(session.qualityScore / 100), height: 6)
                            .cornerRadius(3)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private func stageDistributionCard(_ session: SleepSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stage Distribution")
                .font(.headline)
            
            if let stages = session.sleepStages?.allObjects as? [SleepStage] {
                let distribution = calculateDistribution(stages)
                
                VStack(spacing: 16) {
                    ForEach(distribution.sorted(by: { $0.percentage > $1.percentage }), id: \.stage) { item in
                        StageDistributionRow(
                            stageType: item.stage,
                            percentage: item.percentage,
                            duration: item.duration
                        )
                    }
                }
            } else {
                Text("No distribution data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("No stage distribution data available")
                    .accessibilityIdentifier("noDistributionData")
            }
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(UIColor.secondarySystemBackground))
        }
    }
    
    private func sortedStages(_ session: SleepSession) -> [SleepStage]? {
        guard let stages = session.sleepStages?.allObjects as? [SleepStage] else {
            return nil
        }
        return stages.sorted { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }
    }
    
    private func calculateDistribution(_ stages: [SleepStage]) -> [(stage: String, percentage: Double, duration: TimeInterval)] {
        let totalDuration = stages.reduce(0) { $0 + $1.duration }
        guard totalDuration > 0 else { return [] }
        
        let grouped = Dictionary(grouping: stages) { $0.stageType ?? "Unknown" }
        
        return grouped.map { stage, stageList in
            let duration = stageList.reduce(0) { $0 + $1.duration }
            let percentage = (duration / totalDuration) * 100
            return (stage: stage, percentage: percentage, duration: duration)
        }
    }
}

struct SleepStagesTimeline: View {
    let stages: [SleepStage]
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color(UIColor.systemBackground))
                    .cornerRadius(8)
                
                // Stages
                HStack(spacing: 1) {
                    ForEach(stages, id: \.id) { stage in
                        Rectangle()
                            .fill(colorForStage(stage.stageType ?? ""))
                    }
                }
                .cornerRadius(8)
            }
        }
    }
    
    private func colorForStage(_ stage: String) -> Color {
        switch stage {
        case "AWAKE": return .gray
        case "LIGHT": return .blue
        case "DEEP": return .purple
        case "REM": return .pink
        default: return .gray.opacity(0.3)
        }
    }
}

struct CircadianInfoCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Learn About Your Sleep Rhythm", systemImage: "clock.fill")
                .font(.headline)
                .foregroundColor(.blue)
            
            Text("Understand how your body's natural clock affects your sleep patterns")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Open Sleep Rhythm Guide")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .accessibilityLabel("Navigate to guide")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Learn about your sleep rhythm. Understand how your body's natural clock affects your sleep patterns")
        .accessibilityHint("Navigate to circadian rhythm guide")
        .accessibilityIdentifier("circadianInfoCard")
    }
}

struct CompareStagesCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Compare Sleep Stages", systemImage: "arrow.left.arrow.right")
                .font(.headline)
                .foregroundColor(.blue)
            
            Text("Explore the differences between light, deep, and REM sleep")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Text("View Stage Comparison")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .accessibilityLabel("Navigate to comparison")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Compare sleep stages. Explore the differences between light, deep, and REM sleep")
        .accessibilityHint("Navigate to sleep stage comparison")
        .accessibilityIdentifier("compareStagesCard")
    }
}

#Preview {
    NavigationView {
        SleepCyclesView(session: nil)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
