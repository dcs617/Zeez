import SwiftUI
import UniformTypeIdentifiers
import os.log

struct DataImportView: View {
    @Binding var importStatus: String
    @Binding var isImporting: Bool
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedImportType: ImportType = .healthKit
    
    enum DataImportModal {
        case none
        case filePicker
        case healthKitAuth
    }
    
    @State private var activeImportModal: DataImportModal = .none
    
    private let healthKitImporter = HealthKitDataImporter.shared
    private let pillowImporter = PillowDataImporter.shared
    private let realDataManager = RealDataManager.shared
    
    enum ImportType {
        case healthKit
        case pillowJSON
        case pillowCSV
        
        var title: String {
            switch self {
            case .healthKit: return "HealthKit"
            case .pillowJSON: return "Pillow (JSON)"
            case .pillowCSV: return "Pillow (CSV)"
            }
        }
        
        var description: String {
            switch self {
            case .healthKit: 
                return "Import sleep data from Apple Health"
            case .pillowJSON: 
                return "Import comprehensive data from Pillow app (JSON export)"
            case .pillowCSV: 
                return "Import basic sleep times from Pillow app (CSV export)"
            }
        }
        
        var allowedContentTypes: [UTType] {
            switch self {
            case .healthKit: return []
            case .pillowJSON: return [.json]
            case .pillowCSV: return [.commaSeparatedText]
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Import Sleep Data")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Choose how you'd like to import your existing sleep data into Zeez")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Import options
                LazyVStack(spacing: 12) {
                    ForEach([ImportType.healthKit, .pillowJSON, .pillowCSV], id: \.self) { type in
                        ImportOptionCard(
                            type: type,
                            isSelected: selectedImportType == type,
                            isImporting: isImporting
                        ) {
                            selectedImportType = type
                        }
                    }
                }
                .padding(.horizontal)
                
                // Instructions
                if selectedImportType != .healthKit {
                    instructionsSection
                }
                
                Spacer()
                
                // Import button
                Button(action: performImport) {
                    HStack {
                        if isImporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isImporting ? "Importing..." : "Start Import")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isImporting)
                .padding(.horizontal)
                
                // Status
                if !importStatus.isEmpty {
                    Text(importStatus)
                        .font(.caption)
                        .foregroundColor(importStatus.contains("Error") ? .red : .green)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: Binding<Bool>(
                    get: { activeImportModal == .filePicker },
                    set: { if !$0 { activeImportModal = .none } }
                ),
                allowedContentTypes: selectedImportType.allowedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
                activeImportModal = .none
            }
            .alert("HealthKit Authorization", isPresented: Binding<Bool>(
                get: { activeImportModal == .healthKitAuth },
                set: { if !$0 { activeImportModal = .none } }
            )) {
                Button("Open Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                    activeImportModal = .none
                }
                Button("Cancel", role: .cancel) {
                    activeImportModal = .none
                }
            } message: {
                Text("HealthKit access is required to import your sleep data. Please enable it in Settings > Health > Data Access & Devices > Zeez.")
            }
        }
    }
    
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Instructions")
                .font(.headline)
                .padding(.horizontal)
            
            Text(PillowDataImporter.pillowExportInstructions())
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
        }
    }
    
    private func performImport() {
        switch selectedImportType {
        case .healthKit:
            importFromHealthKit()
        case .pillowJSON, .pillowCSV:
            activeImportModal = .filePicker
        }
    }
    
    private func importFromHealthKit() {
        isImporting = true
        importStatus = "Requesting HealthKit authorization..."
        
        healthKitImporter.requestFullAuthorization { [self] success, error in
            DispatchQueue.main.async {
                if success {
                    importStatus = "Importing HealthKit data..."
                    
                    // Import last 90 days
                    let startDate = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
                    
                    healthKitImporter.importSleepData(from: startDate, to: Date()) { result in
                        DispatchQueue.main.async {
                            isImporting = false
                            
                            switch result {
                            case .success(let count):
                                importStatus = "Successfully imported \(count) sleep sessions from HealthKit"
                                if count > 0 {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        dismiss()
                                    }
                                }
                            case .failure(let error):
                                importStatus = "Error importing HealthKit data: \(error.localizedDescription)"
                                ZeezLogger.error(ZeezLogger.error, "HealthKit import failed: \(error.localizedDescription)")
                            }
                        }
                    }
                } else {
                    isImporting = false
                    importStatus = "HealthKit authorization required"
                    activeImportModal = .healthKitAuth
                }
            }
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            isImporting = true
            importStatus = "Processing file..."
            
            switch selectedImportType {
            case .pillowJSON:
                pillowImporter.importFromJSONFile(url: url) { result in
                    handleImportResult(result)
                }
            case .pillowCSV:
                pillowImporter.importFromCSVFile(url: url) { result in
                    handleImportResult(result)
                }
            case .healthKit:
                break // Should not reach here
            }
            
        case .failure(let error):
            importStatus = "Error selecting file: \(error.localizedDescription)"
            ZeezLogger.error(ZeezLogger.error, "File selection failed: \(error.localizedDescription)")
        }
    }
    
    private func handleImportResult(_ result: Result<Int, Error>) {
        DispatchQueue.main.async {
            isImporting = false
            
            switch result {
            case .success(let count):
                importStatus = "Successfully imported \(count) sleep sessions"
                if count > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }
            case .failure(let error):
                importStatus = "Error importing data: \(error.localizedDescription)"
                ZeezLogger.error(ZeezLogger.error, "Import failed: \(error.localizedDescription)")
            }
        }
    }
}

private struct ImportOptionCard: View {
    let type: DataImportView.ImportType
    let isSelected: Bool
    let isImporting: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(type.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        } else {
                            Image(systemName: "circle")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding()
            }
        }
        .disabled(isImporting)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type.title) import option")
        .accessibilityHint(type.description)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    DataImportView(
        importStatus: .constant(""),
        isImporting: .constant(false)
    )
}