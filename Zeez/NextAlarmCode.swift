import SwiftUI

struct NextAlarmCard: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AlarmConfiguration.time, ascending: true)],
        predicate: NSPredicate(format: "enabled == YES"),
        animation: .default)
    private var alarms: FetchedResults<AlarmConfiguration>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next Alarm")
                .font(.headline)
            
            if let nextAlarm = alarms.first,
               let alarmTime = nextAlarm.time {
                HStack {
                    Image(systemName: "alarm.fill")
                        .foregroundColor(.purple)
                    Text(alarmTime, formatter: FormatterUtils.timeFormatter)
                        .font(.title2)
                        .bold()
                }
                
                if nextAlarm.smartWakeEnabled {
                    Text("Smart Wake enabled")
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No alarms set")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
    }
}