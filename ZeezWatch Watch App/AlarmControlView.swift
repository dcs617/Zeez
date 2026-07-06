import SwiftUI

struct AlarmControlView: View {
    @ObservedObject var connectivityManager = WatchConnectivityManager.shared
    private let hapticManager = WatchHapticManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "alarm.fill")
                        .foregroundColor(.orange)
                    Text("Alarm")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                if let nextAlarmTime = connectivityManager.alarmStatus.nextAlarmTime,
                   connectivityManager.alarmStatus.isEnabled {
                    // Next Alarm Display
                    VStack(spacing: 8) {
                        Text("Next Alarm")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatAlarmTime(nextAlarmTime))
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text(connectivityManager.alarmStatus.alarmName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if connectivityManager.alarmStatus.smartWakeEnabled {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .font(.caption2)
                                Text("Smart Wake: \(connectivityManager.alarmStatus.smartWakeWindow)m")
                                    .font(.caption2)
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    // Time Until Alarm
                    if let timeUntil = timeUntilAlarm(nextAlarmTime) {
                        Text(timeUntil)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                } else {
                    // No Active Alarm
                    VStack(spacing: 8) {
                        Image(systemName: "alarm")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        
                        Text("No Active Alarm")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Set an alarm on your iPhone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                
                // Wake Pattern Status
                if connectivityManager.isReceivingWakePattern {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "heart.circle.fill")
                                .foregroundColor(.red)
                            Text("Wake Pattern Active")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        // Alarm Response Buttons
                        HStack(spacing: 12) {
                            Button(action: {
                                connectivityManager.snoozeAlarm()
                            }) {
                                VStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                    Text("Snooze")
                                        .font(.caption2)
                                }
                                .foregroundColor(.orange)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: {
                                connectivityManager.acknowledgeAlarm()
                            }) {
                                VStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Stop")
                                        .font(.caption2)
                                }
                                .foregroundColor(.green)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Refresh Button
                Button(action: {
                    hapticManager.playActionFeedback()
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
                
                // Haptic Test Section (Debug builds only)
                #if DEBUG
                VStack(spacing: 8) {
                    Text("Haptic Test")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Button("Gentle") {
                            hapticManager.testHapticPattern(.gentle)
                        }
                        .font(.caption2)
                        .foregroundColor(.green)
                        
                        Button("Moderate") {
                            hapticManager.testHapticPattern(.moderate)
                        }
                        .font(.caption2)
                        .foregroundColor(.orange)
                        
                        Button("Strong") {
                            hapticManager.testHapticPattern(.strong)
                        }
                        .font(.caption2)
                        .foregroundColor(.red)
                    }
                }
                .padding(.top)
                #endif
            }
            .padding()
        }
        .navigationTitle("Alarm")
        .onAppear {
            connectivityManager.requestLatestData()
        }
    }
    
    private func formatAlarmTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func timeUntilAlarm(_ alarmTime: Date) -> String? {
        let now = Date()
        let timeInterval = alarmTime.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            return nil
        }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "in \(hours)h \(minutes)m"
        } else {
            return "in \(minutes)m"
        }
    }
}