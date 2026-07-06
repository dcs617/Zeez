import SwiftUI

struct WatchSettingsView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "gear")
                        .foregroundColor(.gray)
                    Text("Settings")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                // Connection Status
                VStack(spacing: 8) {
                    HStack {
                        Circle()
                            .fill(connectivityManager.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(connectivityManager.isConnected ? "Connected" : "Disconnected")
                            .font(.caption)
                            .foregroundColor(connectivityManager.isConnected ? .green : .red)
                    }
                    
                    Text("iPhone Connection")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // App Info
                VStack(spacing: 8) {
                    Text("Zeez Watch")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Sleep Tracking Companion")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Version 1.0")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Quick Actions
                VStack(spacing: 12) {
                    Text("Quick Actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        connectivityManager.requestLatestData()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh Data")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Data Status
                VStack(spacing: 8) {
                    Text("Data Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: connectivityManager.sleepSummary.isDataAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(connectivityManager.sleepSummary.isDataAvailable ? .green : .red)
                                .font(.caption2)
                            Text("Sleep Data")
                                .font(.caption2)
                        }
                        
                        HStack {
                            Image(systemName: connectivityManager.alarmStatus.isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(connectivityManager.alarmStatus.isEnabled ? .green : .red)
                                .font(.caption2)
                            Text("Active Alarm")
                                .font(.caption2)
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                // Instructions
                VStack(spacing: 4) {
                    Text("Instructions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Keep your iPhone nearby for data sync and alarm features")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            .padding()
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    WatchSettingsView()
}