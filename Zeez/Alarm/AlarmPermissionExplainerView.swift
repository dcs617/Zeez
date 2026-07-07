import SwiftUI
import UserNotifications
import os.log

/// Shows an explanation before requesting notification permissions
struct AlarmPermissionExplainerView: View {
    let onAllow: () -> Void
    let onDismiss: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 0) {
                // Card Content
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "bell.badge")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.blue)
                                .scaleEffect(isAnimating ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Enable Alarm Notifications")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("For reliable wake-up alerts")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Benefits
                    VStack(alignment: .leading, spacing: 16) {
                        PermissionBenefitRow(
                            icon: "alarm.fill",
                            iconColor: .orange,
                            title: "Never Miss an Alarm",
                            description: "Get reliable wake-up notifications even when your phone is silent"
                        )
                        
                        PermissionBenefitRow(
                            icon: "speaker.wave.3.fill",
                            iconColor: .green,
                            title: "Critical Alert Sounds",
                            description: "Bypass silent mode for important alarms when you need them most"
                        )
                        
                        PermissionBenefitRow(
                            icon: "repeat",
                            iconColor: .blue,
                            title: "Smart Follow-ups",
                            description: "Automatic reminders if you don't respond to the initial alarm"
                        )
                    }
                    
                    // Buttons
                    VStack(spacing: 12) {
                        Button(action: onAllow) {
                            HStack {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Enable Notifications")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: onDismiss) {
                            Text("Maybe Later")
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 44)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
                )
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

private struct PermissionBenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}

#Preview {
    AlarmPermissionExplainerView(
        onAllow: {},
        onDismiss: {}
    )
}