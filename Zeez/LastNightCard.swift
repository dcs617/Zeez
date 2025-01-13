import SwiftUI

struct LastNightCard: View {
    let session: SleepSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Night's Sleep")
                .font(.headline)
            
            if let startTime = session.startTime,
               let endTime = session.endTime {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(startTime, formatter: FormatterUtils.timeFormatter)
                        Image(systemName: "arrow.right")
                        Text(endTime, formatter: FormatterUtils.timeFormatter)
                    }
                    
                    Text("Duration: \(FormatterUtils.formattedDuration(start: startTime, end: endTime))")

                    HStack {
                        Text("Sleep Score:")
                        Text("\(Int(session.qualityScore))")
                            .bold()
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
    }
}
