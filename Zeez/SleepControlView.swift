import SwiftUI
import CoreData

/// Primary interface for controlling sleep sessions and viewing current status
struct SleepControlView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var batteryMonitor = BatteryMonitor()
    
    @State private var showingGoalSettings = false
    @State private var isPreparingSession = false
    @State private var showingSessionSummary = false
    
    let session: SleepSession?
    let sessionStart: Date?
    
    var body: some View {
        VStack(spacing: 24) {
            // Status indicators for device readiness
            HStack(spacing: 16) {
                StatusIndicator(
                    icon: "battery.75",
                    label: "\(Int(batteryMonitor.batteryLevel * 100))%",
                    color: batteryMonitor.statusColor
                )
                
                if let session = session {
                    StatusIndicator(
                        icon: "sensors",
                        label: "Monitoring",
                        color: .green
                    )
                    
                    if let start = sessionStart {
                        ElapsedTimeView(startTime: start)
                    }
                }
            }
            
            // Session controls
            if let activeSession = session {
                activeSessionControls(activeSession)
            } else {
                startSessionControls
            }
            
            // Sleep goal information
            if session == nil {
                sleepGoalSection
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .sheet(isPresented: $showingGoalSettings) {
            SleepGoalSettingsView()
        }
    }
    
    private var startSessionControls: some View {
        VStack(spacing: 16) {
            Button(action: prepareSession) {
                HStack {
                    Image(systemName: "moon.stars.fill")
                    Text(isPreparingSession ? "Starting Sleep Mode..." : "Start Sleep Mode")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isPreparingSession)
            
            if isPreparingSession {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
    }
    
    private func activeSessionControls(_ session: SleepSession) -> some View {
        VStack(spacing: 16) {
            Button(action: { endSession(session) }) {
                HStack {
                    Image(systemName: "stop.circle.fill")
                    Text("End Sleep Session")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Button(action: addSleepNote) {
                Label("Add Note", systemImage: "note.text")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
            }
        }
    }
    
    private var sleepGoalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sleep Goal")
                    .font(.headline)
                Spacer()
                Button(action: { showingGoalSettings = true }) {
                    Image(systemName: "gear")
                }
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Target Bedtime")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("10:30 PM")
                        .font(.title3)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Target Duration")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("8h 00m")
                        .font(.title3)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
    }
    
    private func prepareSession() {
        isPreparingSession = true
        
        // Start environmental monitoring
        EnvironmentalMonitor.shared.checkSensorAvailability { available in
            if available {
                SleepSessionManager.shared.startSession { result in
                    switch result {
                    case .success(let session):
                        // Start all monitoring systems
                        EnvironmentalMonitor.shared.startMonitoring(for: session)
                        MovementDataManager.shared.startMonitoring(for: session)
                        
                    case .failure(let error):
                        ErrorManager.shared.showError(.sleepSessionCreationFailed)
                    }
                    isPreparingSession = false
                }
            } else {
                ErrorManager.shared.showError(.sensorDataUnavailable)
                isPreparingSession = false
            }
        }
    }
    
    private func endSession(_ session: SleepSession) {
        SleepSessionManager.shared.endSession(session) { result in
            switch result {
            case .success(let completedSession):
                EnvironmentalMonitor.shared.stopMonitoring()
                MovementDataManager.shared.stopMonitoring()
                showingSessionSummary = true
                
            case .failure(let error):
                ErrorManager.shared.showError(.sleepSessionUpdateFailed)
            }
        }
    }
    
    private func addSleepNote() {
        // To be implemented
    }
}

struct StatusIndicator: View {
    let icon: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(label)
                .font(.subheadline)
        }
    }
}

struct ElapsedTimeView: View {
    let startTime: Date
    @State private var elapsedTime: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(formattedElapsedTime)
            .monospacedDigit()
            .onReceive(timer) { _ in
                elapsedTime = Date().timeIntervalSince(startTime)
            }
    }
    
    private var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}

class BatteryMonitor: ObservableObject {
    @Published var batteryLevel: Double = 1.0
    
    var statusColor: Color {
        switch batteryLevel {
        case 0.0...0.2: return .red
        case 0.2...0.4: return .orange
        default: return .green
        }
    }
    
    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        batteryLevel = Double(UIDevice.current.batteryLevel)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(batteryLevelDidChange),
            name: UIDevice.batteryLevelDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func batteryLevelDidChange() {
        batteryLevel = Double(UIDevice.current.batteryLevel)
    }
}
