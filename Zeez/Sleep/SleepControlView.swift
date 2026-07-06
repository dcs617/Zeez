import SwiftUI
import CoreData
import os.log

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
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Battery level \(Int(batteryMonitor.batteryLevel * 100)) percent")
                .accessibilityHint("Device battery status for sleep tracking")
                .accessibilityIdentifier("batteryIndicator")
                
                if session != nil {
                    StatusIndicator(
                        icon: "sensors",
                        label: "Monitoring",
                        color: .green
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Sleep sensors actively monitoring")
                    .accessibilityHint("Sleep tracking is currently active")
                    .accessibilityIdentifier("monitoringIndicator")
                    
                    if let start = sessionStart {
                        ElapsedTimeView(startTime: start)
                            .accessibilityLabel("Sleep session elapsed time")
                            .accessibilityIdentifier("elapsedTimeView")
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("statusIndicators")
            
            // Session controls
            if let activeSession = session {
                activeSessionControls(activeSession)
                    .accessibilityIdentifier("activeSessionControls")
            } else {
                startSessionControls
                    .accessibilityIdentifier("startSessionControls")
            }
            
            // Sleep goal information
            if session == nil {
                sleepGoalSection
                    .accessibilityIdentifier("sleepGoalSection")
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sleepControlView")
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
            .accessibilityLabel(isPreparingSession ? "Starting sleep tracking session" : "Start sleep tracking session")
            .accessibilityHint(isPreparingSession ? "Sleep mode is being prepared" : "Begin monitoring your sleep with sensors and environmental data")
            .accessibilityIdentifier("startSleepButton")
            
            if isPreparingSession {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .accessibilityLabel("Preparing sleep session")
                    .accessibilityHint("Setting up sensors and starting sleep tracking")
                    .accessibilityIdentifier("preparingProgress")
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
            .accessibilityLabel("End sleep session")
            .accessibilityHint("Stop sleep tracking and save the recorded session data")
            .accessibilityIdentifier("endSleepButton")
            
            Button(action: addSleepNote) {
                Label("Add Note", systemImage: "note.text")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(10)
            }
            .accessibilityLabel("Add sleep note")
            .accessibilityHint("Record a note or observation about your current sleep session")
            .accessibilityIdentifier("addNoteButton")
        }
    }
    
    private var sleepGoalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sleep Goal")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("sleepGoalHeader")
                Spacer()
                Button(action: { showingGoalSettings = true }) {
                    Image(systemName: "gear")
                }
                .accessibilityLabel("Sleep goal settings")
                .accessibilityHint("Configure your target bedtime and sleep duration")
                .accessibilityIdentifier("goalSettingsButton")
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Target Bedtime")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("bedtimeLabel")
                    Text("10:30 PM")
                        .font(.title3)
                        .accessibilityLabel("Target bedtime 10:30 PM")
                        .accessibilityIdentifier("bedtimeValue")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Target bedtime 10:30 PM")
                .accessibilityIdentifier("bedtimeSection")
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Target Duration")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("durationLabel")
                    Text("8h 00m")
                        .font(.title3)
                        .accessibilityLabel("Target duration 8 hours")
                        .accessibilityIdentifier("durationValue")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Target sleep duration 8 hours")
                .accessibilityIdentifier("durationSection")
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sleepGoalContainer")
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
                        ZeezLogger.error(ZeezLogger.error, "Failed to create sleep session", error: error)
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
                ZeezLogger.info(ZeezLogger.sleepTracking, "Successfully ended sleep session: \(completedSession.id?.uuidString ?? "unknown")")
                EnvironmentalMonitor.shared.stopMonitoring()
                MovementDataManager.shared.stopMonitoring()
                showingSessionSummary = true
                
            case .failure(let error):
                ZeezLogger.error(ZeezLogger.error, "Failed to end sleep session", error: error)
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
                .accessibilityHidden(true)
            Text(label)
                .font(.subheadline)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("statusIndicator_\(icon)")
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
            .accessibilityLabel("Sleep session duration \(accessibleElapsedTime)")
            .accessibilityValue(formattedElapsedTime)
            .accessibilityIdentifier("elapsedTimer")
    }
    
    private var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    private var accessibleElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        let hourText = hours == 1 ? "hour" : "hours"
        let minuteText = minutes == 1 ? "minute" : "minutes"
        return "\(hours) \(hourText) and \(minutes) \(minuteText)"
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
