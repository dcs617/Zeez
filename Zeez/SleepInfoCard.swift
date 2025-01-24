//
//  SleepInfoCard.swift
//  Zeez
//
//  Created by Daniel on 1/14/25.
//
import SwiftUI

struct SleepInfoCard: View {
    let session: SleepSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last sleep information")
                .font(.headline)
            
            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 16) {
                GridRow {
                    SleepInfoRow(
                        icon: "moon.zzz.fill",
                        title: "Time in sleep",
                        value: formatDuration(session.timeInSleep)
                    )
                    SleepInfoRow(
                        icon: "alarm.fill",
                        title: "Wake up time",
                        value: formatTime(session.endTime)
                    )
                }
                
                GridRow {
                    SleepInfoRow(
                        icon: "bed.double.fill",
                        title: "Went to bed",
                        value: formatTime(session.startTime)
                    )
                    SleepInfoRow(
                        icon: "zzz",
                        title: "Fell asleep",
                        value: calculateFellAsleepTime()
                    )
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func formatTime(_ date: Date?) -> String {
        guard let date = date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        return "\(hours)h \(minutes)m"
    }
    
    private func calculateFellAsleepTime() -> String {
        // TODO: This should be calculated based on first detected sleep stage
        return "25 min"
    }
}

struct SleepInfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption)
            .foregroundColor(.gray)
            
            Text(value)
                .font(.subheadline)
                .bold()
        }
    }
}
