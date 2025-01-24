import SwiftUI
import CoreData

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
            
            if let remaining = stateManager.remainingSnoozeTime {
                Text(timeString(from: remaining))
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            Button(action: stopAlarm) {
                Text("Stop Snooze")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 8)
    }
    
    private var timeDisplay: some View {
        VStack(spacing: 8) {
            Text(Date(), style: .time)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text(Date(), style: .date)
                .font(.title3)
                .foregroundColor(.gray)
        }
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
        
        if let activeSession = try? viewContext.fetch(request).first {
            activeSession.isActive = false
            activeSession.endTime = Date()
            try? viewContext.save()
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
