import SwiftUI
import CoreData
import Charts

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
                    
                    Button("View Analysis") {
                        showingAnalysis = true
                    }
                    .buttonStyle(.borderedProminent)
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
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Average")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(actualHours, specifier: "%.1f") hours")
                        .font(.headline)
                }
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
                
                Spacer()
                
                Button(action: { showingHistory = true }) {
                    Text("View History")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
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
            }
            
            Text(getSeverity().description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .onTapGesture {
            showingAnalysis = true
        }
    }
    
    private var recoveryEstimate: some View {
        VStack(spacing: 8) {
            Text("Recovery Plan")
                .font(.headline)
            
            Text("It will take approximately \(recoveryDays) days to recover")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(getSeverity().recommendations.prefix(3), id: \.self) { recommendation in
                    Label(recommendation, systemImage: "arrow.right.circle")
                        .font(.subheadline)
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var impactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Impact")
                .font(.headline)
            
            ForEach(getSeverity().impacts, id: \.self) { impact in
                Label(impact, systemImage: "exclamationmark.circle")
                    .font(.subheadline)
                    .foregroundColor(getSeverity().color)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func updateData() {
        debtHours = SleepDebtAnalyzer.shared.calculateCurrentDebt(context: viewContext)
        recommendedHours = SleepDebtAnalyzer.shared.getRecommendedSleepDuration(context: viewContext)
        actualHours = SleepDebtAnalyzer.shared.getAverageSleepTime(forDays: 7, context: viewContext)
        debtHistory = SleepDebtAnalyzer.shared.getDebtHistory(forDays: 30, context: viewContext)
        recoveryDays = SleepDebtAnalyzer.shared.calculateRecoveryDays(debtHours: debtHours)
    }
    
    private func getSeverity() -> DebtSeverity {
        SleepDebtAnalyzer.shared.getDebtSeverity(debtHours: debtHours)
    }
}

#Preview {
    LearnSleepDebtView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}