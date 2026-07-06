import SwiftUI

struct SleepSummaryView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "moon.fill")
                        .foregroundColor(.blue)
                    Text("Latest Session")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                if connectivityManager.sleepSummary.isDataAvailable {
                    // Sleep Duration
                    VStack(spacing: 4) {
                        Text(formatDuration(connectivityManager.sleepSummary.lastNightDuration))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("Session Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if connectivityManager.sleepSummary.isQualityScoreAvailable {
                        VStack(spacing: 4) {
                            HStack {
                                Text("\(Int(connectivityManager.sleepSummary.qualityScore))")
                                    .font(.title)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.blue)
                                Text("/100")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text("Experimental Zeez Estimate")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Experimental Zeez estimated sleep score \(Int(connectivityManager.sleepSummary.qualityScore)) out of 100")
                    } else {
                        VStack(spacing: 4) {
                            Text("--")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Text("Estimate Not Available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Experimental Zeez estimate not available")
                    }
                    
                    // Sleep Times
                    if let bedTime = connectivityManager.sleepSummary.bedTime,
                       let wakeTime = connectivityManager.sleepSummary.wakeTime {
                        HStack(spacing: 20) {
                            VStack(spacing: 2) {
                                Text(formatTime(bedTime))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("Bedtime")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 2) {
                                Text(formatTime(wakeTime))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("Wake Up")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } else {
                    // No Data Available
                    VStack(spacing: 8) {
                        Image(systemName: "moon.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        
                        Text("No Sleep Data")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Start tracking on your iPhone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                
                // Refresh Button
                Button(action: {
                    connectivityManager.requestLatestData()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
        }
        .navigationTitle("Sleep")
        .onAppear {
            connectivityManager.requestLatestData()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
}
