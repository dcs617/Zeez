import SwiftUI
import os.log

/// Displays information about the next scheduled alarm
struct NextAlarmSummary: View {
    let alarms: [AlarmConfiguration]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next Alarm")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let nextAlarm = findNextAlarm() {
                HStack {
                    VStack(alignment: .leading) {
                        if let time = nextAlarm.time {
                            Text(time, formatter: FormatterUtils.timeFormatter)
                                .font(.title)
                                .fontWeight(.semibold)
                        }
                        
                        Text(AlarmTimeCalculator.timeUntilNextAlarm(nextAlarm))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if nextAlarm.smartWakeEnabled {
                        SmartWakeIndicator(window: nextAlarm.smartWakeWindow)
                    }
                }
            } else {
                HStack {
                    VStack(alignment: .leading) {
                        Text("--:--")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Text("No alarms scheduled")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func findNextAlarm() -> AlarmConfiguration? {
        return alarms
            .filter { $0.enabled }
            .min { alarm1, alarm2 in
                guard let time1 = alarm1.time,
                      let time2 = alarm2.time else { return false }
                
                let next1 = AlarmTimeCalculator.nextOccurrence(of: time1, for: alarm1)
                let next2 = AlarmTimeCalculator.nextOccurrence(of: time2, for: alarm2)
                
                return next1 < next2
            }
    }
}

#Preview("No Alarms") {
    NextAlarmSummary(alarms: [])
        .padding()
        .background(Color(.systemBackground))
}

#Preview("With Alarm") {
    let context = PersistenceController.preview.container.viewContext
    let alarm = AlarmConfiguration(context: context)
    alarm.time = Date()
    alarm.enabled = true
    alarm.smartWakeEnabled = true
    alarm.smartWakeWindow = 30
    
    return NextAlarmSummary(alarms: [alarm])
        .padding()
        .background(Color(.systemBackground))
}
