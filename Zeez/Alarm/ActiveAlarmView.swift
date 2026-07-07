import Foundation
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
    @State private var vibrationTimer: Timer?
    // Removed @State audioPlayer - now using centralized AlarmAudioController
    
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
                                
                                Text("\(alarm.snoozeDurationMinutes) min")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                if snoozeCount > 0 {
                                    Text("(\(snoozeCount))")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                    }
                    .accessibilityLabel("Snooze alarm")
                    .accessibilityHint("Snooze for \(alarm.snoozeDurationMinutes) minutes")
                    
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
            ZeezLogger.info(ZeezLogger.alarm, "📱 ActiveAlarmView appeared for alarm \(alarm.id?.uuidString ?? "Unknown")")
            startAnimation()
            startContinuousAlarmAudio()
        }
        .onDisappear {
            ZeezLogger.info(ZeezLogger.alarm, "📱 ActiveAlarmView disappeared")
            AlarmAudioController.shared.stop()
            stopContinuousVibration()
        }
        // Critical: Make it hard to dismiss accidentally - require Stop/Snooze only
        .interactiveDismissDisabled(true)
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
    
    private func startContinuousAlarmAudio() {
        if alarm.vibrationOnly {
            // Start continuous vibration for vibration-only alarms
            startContinuousVibration()
            return
        }
        
        // Get the user's configured volume for this alarm
        let volume = Float(alarm.musicVolume)
        
        // Use the centralized audio controller for continuous looping
        // Try to use the long bundled sound, fallback to default if not available
        if AlarmAudioController.shared.canPlay(bundledName: AlarmNotificationUtils.longInAppBundledName) {
            AlarmAudioController.shared.startLooping(bundledName: AlarmNotificationUtils.longInAppBundledName, volume: volume)
        } else {
            // Fallback: Use the user's selected alarm sound or a bundled sound
            let selectedSound = alarm.alarmSound ?? "Alarm_Classic.caf"
            if selectedSound.hasSuffix(".caf") {
                let soundName = String(selectedSound.dropLast(4)) // Remove .caf extension
                AlarmAudioController.shared.startLooping(bundledName: soundName, fileExtension: "caf", volume: volume)
            } else {
                // Final fallback to a guaranteed bundled sound
                AlarmAudioController.shared.startLooping(bundledName: "Alarm_Classic", fileExtension: "caf", volume: volume)
            }
        }
    }
    
    private func startContinuousVibration() {
        // Create a repeating vibration pattern for vibration-only alarms.
        // Kept in @State — the old objc_setAssociatedObject(self, …) approach boxed
        // this struct into a fresh object per call, so the timer could never be
        // found again and vibration survived dismissal.
        vibrationTimer?.invalidate()
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
        ZeezLogger.info(ZeezLogger.alarm, "📳 Started continuous vibration for vibration-only alarm")
    }
    
    private func handleSnooze() {
        snoozeCount += 1
        AlarmAudioController.shared.stop()
        stopContinuousVibration()
        
        // Log the custom snooze duration
        ZeezLogger.info(ZeezLogger.alarm, "Alarm snoozed for \(alarm.snoozeDurationMinutes) minutes")
        
        onSnooze()
    }
    
    private func handleDismiss() {
        AlarmAudioController.shared.stop()
        stopContinuousVibration()
        onDismiss()
    }
    
    private func stopContinuousVibration() {
        if let timer = vibrationTimer {
            timer.invalidate()
            vibrationTimer = nil
            ZeezLogger.info(ZeezLogger.alarm, "🛑 Stopped continuous vibration")
        }
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
        onSnooze: {},
        onDismiss: {}
    )
    .environment(\.managedObjectContext, context)
}
