import SwiftUI
import CoreData
import Charts
import os.log

struct LearnSleepDebtView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var debtHours: Double = 0
    @State private var recommendedHours: Double = 8.0
    @State private var actualHours: Double = 0
    @State private var showingHistory = false
    @State private var showingAnalysis = false
    @State private var debtHistory: [(Date, Double)] = []
    @State private var recoveryDays: Int = 0
    
    let timer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                sleepSummary
                
                debtVisualization
                
                HStack {
                    Button("View History") {
                        showingHistory = true
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("View sleep debt history")
                    .accessibilityHint("See historical sleep debt data and trends")
                    .accessibilityIdentifier("viewSleepDebtHistoryButton")
                    
                    Button("View Analysis") {
                        showingAnalysis = true
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("View detailed analysis")
                    .accessibilityHint("See comprehensive sleep debt analysis and recovery plan")
                    .accessibilityIdentifier("viewSleepDebtAnalysisButton")
                }
                
                recoveryEstimate
                
                impactSection
            }
            .padding()
        }
        .onAppear {
            updateData()
        }
        .onReceive(timer) { _ in
            updateData()
        }
        .sheet(isPresented: $showingHistory) {
            NavigationView {
                LearnSleepDebtHistoryView(
                    history: debtHistory,
                    recommendedHours: recommendedHours
                )
            }
        }
        .sheet(isPresented: $showingAnalysis) {
            LearnSleepDebtAnalysisView(
                debtHours: debtHours,
                recoveryDays: recoveryDays,
                recommendedHours: recommendedHours
            )
        }
    }
    
    private var sleepSummary: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Recommended")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(recommendedHours, specifier: "%.1f") hours")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Recommended sleep: \(recommendedHours, specifier: "%.1f") hours")
                .accessibilityIdentifier("recommendedSleepHours")
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Average")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(actualHours, specifier: "%.1f") hours")
                        .font(.headline)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Average sleep: \(actualHours, specifier: "%.1f") hours")
                .accessibilityIdentifier("averageSleepHours")
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Current Debt")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(debtHours, specifier: "%.1f") hours")
                        .font(.headline)
                        .foregroundColor(getSeverity().color)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Current sleep debt: \(debtHours, specifier: "%.1f") hours")
                .accessibilityIdentifier("currentSleepDebt")
                
                Spacer()
                
                Button(action: { showingHistory = true }) {
                    Text("View History")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("View sleep debt history")
                .accessibilityHint("See historical sleep debt data")
                .accessibilityIdentifier("viewHistoryButton")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var debtVisualization: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 20)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: min(debtHours / (recommendedHours * 7), 1))
                    .stroke(getSeverity().color, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text(getSeverity() == .minimal ? "Minimal" :
                         getSeverity() == .moderate ? "Moderate" :
                         getSeverity() == .significant ? "Significant" : "Severe")
                        .font(.headline)
                        .foregroundColor(getSeverity().color)
                    Text("Sleep Debt")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Sleep debt severity: \(getSeverity() == .minimal ? "Minimal" : getSeverity() == .moderate ? "Moderate" : getSeverity() == .significant ? "Significant" : "Severe")")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Sleep debt visualization showing \(getSeverity() == .minimal ? "minimal" : getSeverity() == .moderate ? "moderate" : getSeverity() == .significant ? "significant" : "severe") debt level")
            .accessibilityHint("Tap to view detailed analysis")
            .accessibilityIdentifier("sleepDebtVisualization")
            
            Text(getSeverity().description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel(getSeverity().description)
        }
        .onTapGesture {
            showingAnalysis = true
        }
        .accessibilityIdentifier("sleepDebtVisualizationSection")
    }
    
    private var recoveryEstimate: some View {
        VStack(spacing: 8) {
            Text("Recovery Plan")
                .font(.headline)
                .accessibilityLabel("Recovery plan section")
            
            Text("It will take approximately \(recoveryDays) days to recover")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Estimated recovery time: \(recoveryDays) days")
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(getSeverity().recommendations.prefix(3), id: \.self) { recommendation in
                    Label(recommendation, systemImage: "arrow.right.circle")
                        .font(.subheadline)
                        .accessibilityLabel("Recommendation: \(recommendation)")
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("recoveryEstimateSection")
    }
    
    private var impactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Impact")
                .font(.headline)
                .accessibilityLabel("Current impact section")
            
            ForEach(getSeverity().impacts, id: \.self) { impact in
                Label(impact, systemImage: "exclamationmark.circle")
                    .font(.subheadline)
                    .foregroundColor(getSeverity().color)
                    .accessibilityLabel("Impact: \(impact)")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("impactSection")
    }
    
    private func updateData() {
        debtHours = SleepDebtCalculator.shared.calculateCurrentDebt(context: viewContext)
        recommendedHours = SleepDebtCalculator.shared.getRecommendedSleepDuration(context: viewContext)
        actualHours = SleepDebtCalculator.shared.getAverageSleepTime(forDays: 7, context: viewContext)
        debtHistory = SleepDebtCalculator.shared.getDebtHistory(forDays: 30, context: viewContext)
        recoveryDays = SleepDebtCalculator.shared.calculateRecoveryDays(debtHours: debtHours)
    }
    
    private func getSeverity() -> DebtSeverity {
        SleepDebtCalculator.shared.getDebtSeverity(debtHours: debtHours)
    }
}

#Preview {
    LearnSleepDebtView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
