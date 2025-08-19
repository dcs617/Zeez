import SwiftUI
import AVFoundation
import AudioToolbox
import os.log

/// Full-screen alarm interface that appears when an alarm is triggered
/// Provides snooze and dismiss functionality with a design similar to Apple's Clock app
struct ActiveAlarmView: View {
    let alarm: AlarmConfiguration
    let onSnooze: () -> Void
    let onDismiss: () -> Void
    
    @State private var currentTime = Date()
    @State private var isAnimating = false
    @State private var snoozeCount = 0
    @State private var audioPlayer: AVAudioPlayer?
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Background - use a more reliable background
            Rectangle()
                .fill(Color.black)
                .ignoresSafeArea(.all)
            
            VStack(spacing: 0) {
                Spacer()
                
                // Alarm Icon and Animation
                VStack(spacing: 32) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 200, height: 200)
                            .scaleEffect(isAnimating ? 1.2 : 1.0)
                            .opacity(isAnimating ? 0.5 : 0.8)
                        
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 160, height: 160)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .opacity(isAnimating ? 0.7 : 0.9)
                        
                        Image(systemName: "alarm.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                    
                    // Alarm Name
                    VStack(spacing: 8) {
                        Text(alarm.name ?? "Alarm")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text("now")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Current Time Display
                VStack(spacing: 4) {
                    Text(currentTime, style: .time)
                        .font(.system(size: 64, weight: .thin, design: .default))
                        .foregroundColor(.white)
                    
                    Text(currentTime, formatter: dateFormatter)
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                }
                .onReceive(timer) { time in
                    currentTime = time
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 80) {
                    // Snooze Button
                    Button(action: handleSnooze) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.orange)
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "zzz")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(spacing: 2) {
                                Text("Snooze")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                
                                if snoozeCount > 0 {
                                    Text("(\(snoozeCount))")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                    }
                    .accessibilityLabel("Snooze alarm")
                    .accessibilityHint("Snooze for 9 minutes")
                    
                    // Stop Button
                    Button(action: handleDismiss) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Stop")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .accessibilityLabel("Stop alarm")
                    .accessibilityHint("Turn off the alarm")
                }
                .padding(.bottom, 80)
                
                // Emergency escape - double tap anywhere to dismiss
                Text("Double tap anywhere to dismiss")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 20)
            }
            
            // Emergency tap area
            Rectangle()
                .fill(Color.clear)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    ZeezLogger.info(ZeezLogger.alarm, "Emergency double-tap dismiss")
                    handleDismiss()
                }
        }
        .onAppear {
            ZeezLogger.info(ZeezLogger.alarm, "📱 ActiveAlarmView appeared for alarm: \(alarm.name ?? "Unknown")")
            startAnimation()
            playAlarmSound()
        }
        .onDisappear {
            ZeezLogger.info(ZeezLogger.alarm, "📱 ActiveAlarmView disappeared")
            stopAlarmSound()
        }
        // Critical: Make sure the view can be dismissed
        .interactiveDismissDisabled(false)
        // Handle device gestures if configured
        .gesture(
            DragGesture()
                .onEnded { value in
                    handleGesture(value)
                }
        )
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }
    
    private func startAnimation() {
        isAnimating = true
    }
    
    private func playAlarmSound() {
        guard !alarm.vibrationOnly else { return }
        
        do {
            // Configure audio session for alarm playback with maximum priority
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers, .allowBluetooth])
            try AVAudioSession.sharedInstance().setActive(true)
            
            // Create a simple system beep sound for now
            // Use a system sound that we know exists
            if let soundURL = Bundle.main.url(forResource: "system_sound_1005", withExtension: "caf") ??
                              Bundle.main.url(forResource: "alarm", withExtension: "caf") {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.numberOfLoops = -1 // Repeat indefinitely
                audioPlayer?.volume = 1.0
                audioPlayer?.play()
            } else {
                // Fallback: Use system beeps via AudioToolbox
                // Play a repeating system alert sound
                let systemSoundId: SystemSoundID = 1005 // SMS alert
                AudioServicesPlaySystemSound(systemSoundId)
                
                // Set up a timer to repeat the sound every 2 seconds
                Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
                    if self.audioPlayer == nil { // Stop if audio was stopped
                        timer.invalidate()
                        return
                    }
                    AudioServicesPlaySystemSound(systemSoundId)
                }
            }
            
        } catch {
            ZeezLogger.error(ZeezLogger.alarm, "Error playing alarm sound", error: error)
            // Fallback to system beep
            AudioServicesPlaySystemSound(1005)
        }
    }
    
    private func stopAlarmSound() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Error deactivating audio session: \(error)")
        }
    }
    
    private func handleSnooze() {
        snoozeCount += 1
        stopAlarmSound()
        onSnooze()
    }
    
    private func handleDismiss() {
        stopAlarmSound()
        onDismiss()
    }
    
    private func handleGesture(_ value: DragGesture.Value) {
        let snoozeGesture = alarm.snoozeGesture ?? "tap"
        let dismissGesture = alarm.deactivateGesture ?? "long_press"
        
        // Handle swipe gestures
        if abs(value.translation.width) > 100 || abs(value.translation.height) > 100 {
            if snoozeGesture == "swipe" {
                handleSnooze()
            } else if dismissGesture == "swipe" {
                handleDismiss()
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let alarm = AlarmConfiguration(context: context)
    
    // Set properties using Core Data setters
    alarm.setValue("Morning Alarm", forKey: "name")
    alarm.setValue("default", forKey: "alarmSound")
    alarm.setValue(false, forKey: "vibrationOnly")
    alarm.setValue(Date(), forKey: "time")
    alarm.setValue(true, forKey: "enabled")
    
    return ActiveAlarmView(
        alarm: alarm,
        onSnooze: { print("Snoozed") },
        onDismiss: { print("Dismissed") }
    )
    .environment(\.managedObjectContext, context)
}
