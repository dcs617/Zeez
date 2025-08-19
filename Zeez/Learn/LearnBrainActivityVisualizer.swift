import SwiftUI
import CoreData
import os.log

struct LearnBrainActivityVisualizer: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var selectedStage: String = "light"
    @State private var waveData: [(TimeInterval, Double)] = []
    @State private var isAnimating = true
    @State private var showingInfo = false
    @State private var currentSession: SleepSession?
    
    let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                stageSelector
                
                waveformSection
                
                if let session = currentSession {
                    currentSessionInfo(session)
                }
                
                stageDescription
                
                characteristicsList
            }
            .padding()
        }
        .onAppear {
            updateWaveform()
            loadCurrentSession()
        }
        .onReceive(timer) { _ in
            if isAnimating {
                updateWaveform()
            }
        }
        .sheet(isPresented: $showingInfo) {
            BrainActivityStageInfoView(stage: selectedStage)
        }
    }
    
    private var stageSelector: some View {
        HStack {
            Picker("Sleep Stage", selection: $selectedStage) {
                Text("Awake").tag("awake")
                Text("Light Sleep").tag("light")
                Text("Deep Sleep").tag("deep")
                Text("REM Sleep").tag("rem")
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedStage) { oldValue, newValue in
                updateWaveform()
            }

            Button(action: { isAnimating.toggle() }) {
                Image(systemName: isAnimating ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
    }
    
    private var waveformSection: some View {
        VStack(spacing: 16) {
            waveformView
                .frame(height: 200)
                .padding(.horizontal)
            
            HStack {
                Label("\(getFrequencyRange()) Hz", systemImage: "waveform")
                Spacer()
                Label(getAmplitudeRange(), systemImage: "arrow.up.and.down")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
    
    private func currentSessionInfo(_ session: SleepSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Sleep Session")
                .font(.headline)
            
            if let stages = session.sleepStages as? Set<SleepStage>,
               let latestStage = stages.sorted(by: { ($0.startTime ?? Date()) > ($1.startTime ?? Date()) }).first {
                
                HStack {
                    VStack(alignment: .leading) {
                        Text("Current Stage")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(latestStage.stageType ?? "Unknown")
                            .font(.headline)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Duration")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text(formatDuration(latestStage.duration))
                            .font(.headline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var waveformView: some View {
        ZStack {
            // Background grid
            Path { path in
                for x in stride(from: 0, to: UIScreen.main.bounds.width, by: 20) {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: 200))
                }
                for y in stride(from: 0, to: 200, by: 20) {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: Double(UIScreen.main.bounds.width), y: Double(y)))
                }
            }
            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            
            // Waveform
            Path { path in
                let width = UIScreen.main.bounds.width - 32
                let height: CGFloat = 200
                let midY = height / 2
                
                for (index, point) in waveData.enumerated() {
                    let x = width * CGFloat(point.0 / 5.0)
                    let y = midY + CGFloat(point.1)
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(getWaveColor(), lineWidth: 2)
            
            // Centerline
            Path { path in
                path.move(to: CGPoint(x: 0, y: 100))
                path.addLine(to: CGPoint(x: UIScreen.main.bounds.width, y: 100))
            }
            .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5]))
        }
    }
    
    private var stageDescription: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(BrainActivityAnalyzer.shared.getStageInfo(selectedStage).name)
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingInfo = true }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
            }
            
            Text(BrainActivityAnalyzer.shared.getStageInfo(selectedStage).description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var characteristicsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Characteristics")
                .font(.headline)
            
            ForEach(BrainActivityAnalyzer.shared.getStageInfo(selectedStage).characteristics, id: \.self) { characteristic in
                Label(characteristic, systemImage: "circle.fill")
                    .font(.subheadline)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func updateWaveform() {
        waveData = BrainActivityAnalyzer.shared.generateBrainWaveData(for: selectedStage)
    }
    
    private func loadCurrentSession() {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.fetchLimit = 1
        currentSession = try? viewContext.fetch(request).first
    }
    
    private func getWaveColor() -> Color {
        switch selectedStage {
        case "awake": return .blue
        case "light": return .green
        case "deep": return .purple
        case "rem": return .orange
        default: return .gray
        }
    }
    
    private func getFrequencyRange() -> String {
        switch selectedStage {
        case "awake": return "13-30"
        case "light": return "8-13"
        case "deep": return "0.5-4"
        case "rem": return "Mixed"
        default: return "Unknown"
        }
    }
    
    private func getAmplitudeRange() -> String {
        switch selectedStage {
        case "awake": return "Low"
        case "light": return "Medium"
        case "deep": return "High"
        case "rem": return "Variable"
        default: return "Unknown"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
}

struct BrainActivityStageInfoView: View {
    @Environment(\.dismiss) private var dismiss
    let stage: String
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    frequencyBandInfo
                    stageCharacteristics
                    brainActivity
                }
                .padding()
            }
            .navigationTitle(BrainActivityAnalyzer.shared.getStageInfo(stage).name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var frequencyBandInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Frequency Bands")
                .font(.headline)
            
            HStack {
                Image(systemName: "waveform.path")
                
                switch stage.lowercased() {
                case "awake":
                    Text("Beta waves (13-30 Hz)")
                        .foregroundColor(.blue)
                case "light":
                    Text("Alpha/Theta waves (8-13 Hz)")
                        .foregroundColor(.green)
                case "deep":
                    Text("Delta waves (0.5-4 Hz)")
                        .foregroundColor(.purple)
                case "rem":
                    Text("Mixed frequency waves")
                        .foregroundColor(.orange)
                default:
                    Text("Unknown frequency")
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var stageCharacteristics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stage Characteristics")
                .font(.headline)
            
            ForEach(BrainActivityAnalyzer.shared.getStageInfo(stage).characteristics, id: \.self) { characteristic in
                Label(characteristic, systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var brainActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Brain Activity")
                .font(.headline)
            
            Text(BrainActivityAnalyzer.shared.getStageInfo(stage).description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    LearnBrainActivityVisualizer()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
