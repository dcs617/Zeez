import SwiftUI
import CoreData
import os.log

struct WakeUpView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var stateManager = AlarmStateManager.shared
    
    var body: some View {
        if stateManager.isWaking {
            activeWakeView
        } else if stateManager.remainingSnoozeTime != nil {
            snoozeView
        }
    }
    
    private var activeWakeView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            timeDisplay
            
            VStack(spacing: 16) {
                Button(action: stopAlarm) {
                    Text("Stop")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
                .accessibilityLabel("Stop alarm")
                .accessibilityHint("Stop the alarm and end wake up sequence")
                .accessibilityIdentifier("stopAlarmButton")
                
                if let alarm = stateManager.activeAlarm,
                   alarm.snoozeEnabled {
                    Button(action: snoozeAlarm) {
                        Text("Snooze")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .accessibilityLabel("Snooze alarm")
                    .accessibilityHint("Snooze the alarm for a few more minutes")
                    .accessibilityIdentifier("snoozeAlarmButton")
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .background(Color.black)
        .environment(\.colorScheme, .dark)
    }
    
    private var snoozeView: some View {
        VStack(spacing: 16) {
            Text("Snoozing")
                .font(.title2)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("snoozeHeader")
            
            if let remaining = stateManager.remainingSnoozeTime {
                Text(timeString(from: remaining))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityLabel("Time remaining: \(timeString(from: remaining))")
                    .accessibilityIdentifier("snoozeCountdown")
            }
            
            Button(action: stopAlarm) {
                Text("Stop Snooze")
                    .foregroundColor(.red)
            }
            .accessibilityLabel("Stop snooze")
            .accessibilityHint("Cancel snooze and stop the alarm")
            .accessibilityIdentifier("stopSnoozeButton")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("snoozeView")
    }
    
    private var timeDisplay: some View {
        VStack(spacing: 8) {
            Text(Date(), style: .time)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .accessibilityLabel("Current time: \(Date().formatted(date: .omitted, time: .complete))")
                .accessibilityIdentifier("currentTime")
            
            Text(Date(), style: .date)
                .font(.title3)
                .foregroundColor(.gray)
                .accessibilityLabel("Today's date: \(Date().formatted(date: .complete, time: .omitted))")
                .accessibilityIdentifier("currentDate")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timeDisplay")
    }
    
    private func stopAlarm() {
        WakeUpProgressionManager.shared.acknowledgeWakeUp()
        stateManager.stopWaking()
        
        // If we have an active sleep session, end it
        endActiveSleepSession()
    }
    
    private func snoozeAlarm() {
        WakeUpProgressionManager.shared.snoozeWakeUp()
        stateManager.snooze()
    }
    
    private func endActiveSleepSession() {
        let request: NSFetchRequest<SleepSession> = SleepSession.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        
        do {
            if let activeSession = try viewContext.fetch(request).first {
                activeSession.isActive = false
                activeSession.endTime = Date()
                try viewContext.save()
            }
        } catch {
            ZeezLogger.error(ZeezLogger.sleepTracking, "Failed to end sleep session", error: error)
            // Could show an error message to user in production
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    WakeUpView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
