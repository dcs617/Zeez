import SwiftUI
import os.log

struct SimpleDataImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var importStatus: String = ""
    @State private var importDidPartiallyFail = false
    @State private var isImporting = false
    @State private var showingAuthAlert = false
    @State private var authError: Error?
    @State private var isViewReady = false
    
    private let healthKitImporter = HealthKitDataImporter.shared
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
                
                Text("Import Your Sleep Data")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Import your real sleep data from Apple Health")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Status
            if !importStatus.isEmpty {
                Text(importStatus)
                    .font(.body)
                    .foregroundColor(statusColor)
                    .multilineTextAlignment(.leading)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Import status")
                    .accessibilityValue(importStatus)
                    .accessibilityIdentifier("importStatus")
            }
            
            Spacer()
            
            // Import button
            Button(action: importHealthKitData) {
                HStack {
                    if isImporting {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if !isViewReady {
                        Text("Loading...")
                    } else {
                        Text("Import from Apple Health")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isViewReady ? Color.red : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isImporting || !isViewReady)
            
            // Instructions
            Text("This will import your sleep data from the Apple Health app. Make sure you have granted HealthKit permissions in Settings.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Import Data")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            // Delay to ensure sheet presentation is fully settled
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isViewReady = true
                ZeezLogger.info(ZeezLogger.coreData, "✅ Import view ready for interaction")
            }
        }
        .alert("HealthKit Authorization Required", isPresented: $showingAuthAlert) {
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable HealthKit access in Settings > Health > Data Access & Devices > Zeez to import your sleep data.")
        }
    }
    
    private var statusColor: Color {
        if importStatus.hasPrefix("❌") { return .red }
        if importDidPartiallyFail { return .orange }
        return .green
    }

    /// Builds the completion message, naming any data type that did not import.
    ///
    /// The importer used to fire heart-rate and respiratory sub-imports and forget them, so
    /// a user could be told "imported 30 sessions" while both were empty (second-audit B10).
    ///
    /// A re-import reports what changed (§8a): sessions Apple Health extended or corrected are
    /// updated, and ones deleted there are removed. When nothing changed it says so — it used
    /// to fall through to "No sleep data found", which a user with data already imported
    /// would read as their data having vanished.
    static func statusMessage(for result: HealthKitImportResult) -> String {
        let changedSessions = result.sessionCount + result.updatedSessionCount
        guard changedSessions + result.removedSessionCount > 0 else {
            if result.fetchedNightCount > 0 {
                return "✅ Already up to date. Apple Health has no new or changed sleep sessions since your last import."
            }
            return "ℹ️ No sleep data found in Apple Health. Make sure you're using the Sleep app or another sleep tracker that writes to HealthKit."
        }

        var message = result.sessionCount > 0
            ? "✅ Imported \(sessions(result.sessionCount)) from Apple Health."
            : "✅ Updated from Apple Health."
        if result.updatedSessionCount > 0 {
            message += "\n• Updated \(sessions(result.updatedSessionCount)) that changed in Apple Health"
        }
        if result.removedSessionCount > 0 {
            message += "\n• Removed \(sessions(result.removedSessionCount)) deleted in Apple Health"
        }

        // Heart rate and respiratory are fetched only for new and changed sessions.
        guard changedSessions > 0 else { return message }

        message += "\n" + line(for: result.heartRate, type: "Heart rate")
        message += "\n" + line(for: result.respiratory, type: "Respiratory rate")

        if result.hasPartialFailure {
            message += "\n\nYour sessions were saved. You can import again to retry the missing data."
        }
        return message
    }

    private static func sessions(_ count: Int) -> String {
        "\(count) sleep \(count == 1 ? "session" : "sessions")"
    }

    private static func line(for outcome: RelatedDataOutcome, type: String) -> String {
        switch outcome {
        case .imported(let count) where count > 0:
            return "• \(type): \(count) readings"
        case .imported:
            return "• \(type): none recorded for these sessions"
        case .unavailable:
            return "• \(type): not available on this device"
        case .failed:
            return "⚠️ \(type): could not be imported"
        }
    }

    private func importHealthKitData() {
        guard !isImporting && isViewReady else { 
            ZeezLogger.debug(ZeezLogger.coreData, "Import blocked - isImporting: \(isImporting), isViewReady: \(isViewReady)")
            return 
        }
        
        ZeezLogger.info(ZeezLogger.coreData, "🏥 User tapped Import from Apple Health button")
        isImporting = true
        importStatus = "Preparing HealthKit authorization..."
        ZeezLogger.info(ZeezLogger.coreData, "Starting HealthKit data import process")
        
        // CRITICAL: Delay HealthKit authorization to avoid presentation conflicts
        // HealthKit's system UI tries to present while our sheet is being presented
        ZeezLogger.info(ZeezLogger.coreData, "⏳ Waiting for sheet presentation to settle before HealthKit authorization")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ZeezLogger.info(ZeezLogger.coreData, "🏥 Now requesting HealthKit authorization")
            self.healthKitImporter.requestFullAuthorization { success, error in
            DispatchQueue.main.async {
                if success {
                    ZeezLogger.info(ZeezLogger.coreData, "HealthKit authorization successful")
                    self.importStatus = "Importing your sleep data..."
                    
                    // Import last 90 days
                    let startDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
                    
                    self.healthKitImporter.importSleepData(from: startDate, to: Date()) { result in
                        DispatchQueue.main.async {
                            self.isImporting = false
                            
                            switch result {
                            case .success(let importResult):
                                self.importStatus = Self.statusMessage(for: importResult)
                                self.importDidPartiallyFail = importResult.hasPartialFailure
                                ZeezLogger.info(ZeezLogger.coreData, "Imported \(importResult.sessionCount) new, \(importResult.updatedSessionCount) updated, \(importResult.removedSessionCount) removed sessions; HR \(String(describing: importResult.heartRate)), respiratory \(String(describing: importResult.respiratory))")
                            case .failure(let error):
                                self.importStatus = "❌ Error importing: \(error.localizedDescription)"
                                self.importDidPartiallyFail = false
                                ZeezLogger.error(ZeezLogger.error, "HealthKit import failed: \(error.localizedDescription)")
                            }
                        }
                    }
                } else {
                    self.isImporting = false
                    ZeezLogger.error(ZeezLogger.error, "HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                    
                    // Show alert for authorization failure
                    self.authError = error
                    self.showingAuthAlert = true
                }
            }
            }
        }
    }
}

#Preview {
    SimpleDataImportView()
}