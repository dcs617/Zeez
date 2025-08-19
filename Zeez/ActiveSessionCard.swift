import SwiftUI
import os.log

struct ActiveSessionCard: View {
    let session: SleepSession
    @State private var elapsedTime: TimeInterval = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current Sleep Session")
                .font(.headline)
            
            HStack {
                Image(systemName: "moon.stars.fill")
                    .foregroundColor(.purple)
                Text(formattedDuration)
                    .font(.title)
                    .bold()
            }
            
            if let startTime = session.startTime {
                Text("Started at \(startTime, formatter: FormatterUtils.timeFormatter)")
                    .foregroundColor(.secondary)
            }
            
            Button(action: endSession) {
                Text("End Session")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 2)
        .onReceive(timer) { _ in
            updateElapsedTime()
        }
    }
    
    private var formattedDuration: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = Int(elapsedTime) / 60 % 60
        return String(format: "%d:%02d", hours, minutes)
    }
    
    private func updateElapsedTime() {
        guard let startTime = session.startTime else { return }
        elapsedTime = Date().timeIntervalSince(startTime)
    }
    
    private func endSession() {
        SleepSessionManager.shared.endSession(session) { _ in }
    }
}
