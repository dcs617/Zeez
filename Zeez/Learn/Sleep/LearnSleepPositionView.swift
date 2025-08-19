import SwiftUI
import CoreData
import Charts
import os.log

struct LearnSleepPositionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedPosition: SleepPosition = .back
    @State private var showingDetail = false
    @State private var positionDistribution: [SleepPosition: Double] = [:]
    @State private var transitions: [(Date, SleepPosition)] = []
    @State private var isLoading = true
    @State private var qualityScores: [SleepPosition: Double] = [:]
    
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private let analyzer = SleepPositionAnalyzer.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                positionSelector
                
                currentPositionDisplay
                
                distributionSection
                
                VStack(spacing: 16) {
                    qualitySection
                    recommendationsSection
                }
                
                if !transitions.isEmpty {
                    transitionSection
                }
            }
            .padding()
        }
        .navigationTitle("Sleep Positions")
        .onAppear {
            updateData()
        }
        .onReceive(timer) { _ in
            updateData()
        }
        .sheet(isPresented: $showingDetail) {
            LearnSleepPositionDetailView(position: selectedPosition)
        }
    }
    
    private var positionSelector: some View {
        Picker("Sleep Position", selection: $selectedPosition) {
            Text("Back").tag(SleepPosition.back)
            Text("Left Side").tag(SleepPosition.leftSide)
            Text("Right Side").tag(SleepPosition.rightSide)
            Text("Stomach").tag(SleepPosition.stomach)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Select sleep position")
        .accessibilityHint("Choose a sleep position to view detailed information")
        .accessibilityIdentifier("sleepPositionPicker")
    }
    
    private var currentPositionDisplay: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 20)
                    .frame(width: 200, height: 200)
                
                let quality = qualityScores[selectedPosition, default: 0]
                Circle()
                    .trim(from: 0, to: quality / 100)
                    .stroke(getQualityColor(score: quality), style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 8) {
                    Image(systemName: selectedPosition.icon)
                        .font(.system(size: 40))
                        .rotationEffect(getRotation(for: selectedPosition))
                        .accessibilityLabel("\(selectedPosition.rawValue) position icon")
                    
                    Text(selectedPosition.rawValue)
                        .font(.headline)
                    
                    if !isLoading {
                        Text("\(Int(positionDistribution[selectedPosition, default: 0] * 100))% of sleep time")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .accessibilityLabel("\(Int(positionDistribution[selectedPosition, default: 0] * 100)) percent of sleep time")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(selectedPosition.rawValue) position, quality score \(Int(qualityScores[selectedPosition, default: 0])) percent")
                .accessibilityIdentifier("currentPositionDisplay")
            }
            
            Button("Learn More") {
                showingDetail = true
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Learn more about \(selectedPosition.rawValue) position")
            .accessibilityHint("View detailed information about this sleep position")
            .accessibilityIdentifier("learnMorePositionButton")
        }
    }
    
    private var distributionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Position Distribution")
                .font(.headline)
                .accessibilityLabel("Sleep position distribution chart")
            
            if isLoading {
                ProgressView()
                .accessibilityLabel("Loading position distribution data")
            } else {
                Chart {
                    ForEach(Array(positionDistribution.keys), id: \.self) { position in
                        BarMark(
                            x: .value("Position", position.rawValue),
                            y: .value("Percentage", positionDistribution[position, default: 0] * 100)
                        )
                        .foregroundStyle(getQualityColor(score: qualityScores[position, default: 0]))
                    }
                }
                .frame(height: 150)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(createDistributionAccessibilityLabel())
                .accessibilityIdentifier("positionDistributionChart")
            }
        }
        .accessibilityIdentifier("distributionSection")
    }
    
    private var qualitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sleep Quality")
                .font(.headline)
                .accessibilityLabel("Sleep quality section")
            
            Text("Based on your sleep patterns, the \(selectedPosition.rawValue) position has been associated with \(getQualityDescription(for: selectedPosition)) sleep quality.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilityLabel("Based on your sleep patterns, the \(selectedPosition.rawValue) position has \(getQualityDescription(for: selectedPosition)) sleep quality")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("qualitySection")
    }
    
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommendations")
                .font(.headline)
                .accessibilityLabel("Recommendations section")
            
            ForEach(getRecommendations(), id: \.self) { recommendation in
                Label(recommendation, systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .accessibilityLabel("Recommendation: \(recommendation)")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recommendationsSection")
    }
    
    private var transitionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Position Changes")
                .font(.headline)
                .accessibilityLabel("Recent position changes section")
            
            ForEach(transitions.prefix(5), id: \.0) { time, position in
                HStack {
                    Image(systemName: position.icon)
                        .rotationEffect(getRotation(for: position))
                        .accessibilityLabel("\(position.rawValue) position")
                    Text(position.rawValue)
                    Spacer()
                    Text(time.formatted(date: .omitted, time: .shortened))
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Changed to \(position.rawValue) position at \(time.formatted(date: .omitted, time: .shortened))")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("transitionSection")
    }
    
    private func updateData() {
        positionDistribution = analyzer.getPositionDistribution(context: viewContext)
        transitions = analyzer.getPositionTransitions(context: viewContext)
        
        // Update quality scores for each position
        for position in [SleepPosition.back, .leftSide, .rightSide, .stomach] {
            qualityScores[position] = analyzer.getSleepQualityForPosition(position, context: viewContext)
        }
        
        isLoading = false
    }
    
    private func getRotation(for position: SleepPosition) -> Angle {
        switch position {
        case .rightSide: return .degrees(90)
        case .leftSide: return .degrees(-90)
        case .stomach: return .degrees(180)
        case .back: return .degrees(0)
        case .unknown: return .degrees(0)
        }
    }
    
    private func getQualityColor(score: Double) -> Color {
        switch score {
        case 0..<50: return .red
        case 50..<75: return .orange
        case 75..<90: return .yellow
        default: return .green
        }
    }
    
    private func getQualityDescription(for position: SleepPosition) -> String {
        let score = qualityScores[position, default: 0]
        switch score {
        case 0..<50: return "poor"
        case 50..<75: return "moderate"
        case 75..<90: return "good"
        default: return "excellent"
        }
    }
    
    private func getRecommendations() -> [String] {
        let score = qualityScores[selectedPosition, default: 0]
        let time = positionDistribution[selectedPosition, default: 0]
        
        if score < 50 {
            return [
                "Consider reducing time in this position",
                "Try using supportive pillows",
                "Consult with a sleep specialist"
            ]
        } else if time > 0.7 {
            return [
                "Try varying your sleep positions",
                "Use pillows for proper alignment",
                "Monitor sleep quality changes"
            ]
        } else {
            return [
                "Maintain your current sleep habits",
                "Continue using proper support",
                "Track any changes in comfort"
            ]
        }
    }
    
    private func createDistributionAccessibilityLabel() -> String {
        let descriptions = positionDistribution.map { position, percentage in
            "\(position.rawValue): \(Int(percentage * 100)) percent"
        }
        return "Position distribution chart. " + descriptions.joined(separator: ", ")
    }
}

#Preview {
    NavigationView {
        LearnSleepPositionView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
