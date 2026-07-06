import SwiftUI
import os.log

struct SimpleDataImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var importStatus: String = ""
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
                    .foregroundColor(importStatus.contains("Error") ? .red : .green)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
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
                            case .success(let count):
                                if count > 0 {
                                    self.importStatus = "✅ Successfully imported \(count) sleep sessions from HealthKit!"
                                    ZeezLogger.info(ZeezLogger.coreData, "Successfully imported \(count) sleep sessions from HealthKit")
                                } else {
                                    self.importStatus = "ℹ️ No sleep data found in Apple Health. Make sure you're using the Sleep app or another sleep tracker that writes to HealthKit."
                                    ZeezLogger.info(ZeezLogger.coreData, "No HealthKit sleep data found to import")
                                }
                            case .failure(let error):
                                self.importStatus = "❌ Error importing: \(error.localizedDescription)"
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