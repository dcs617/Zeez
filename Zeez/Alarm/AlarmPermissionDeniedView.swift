import SwiftUI
import os.log

/// Shows when user tries to enable alarms but notifications are denied
struct AlarmPermissionDeniedView: View {
    let onOpenSettings: () -> Void
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
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "bell.slash")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundColor(.red)
                                .scaleEffect(isAnimating ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Notifications Required")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Alarms need notification permissions to work")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 16) {
                        Text("To enable alarms:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        PermissionInstructionStep(
                            number: "1",
                            title: "Open Settings",
                            description: "Tap the button below to open your iPhone Settings"
                        )
                        
                        PermissionInstructionStep(
                            number: "2", 
                            title: "Find Zeez",
                            description: "Look for Zeez in your apps list"
                        )
                        
                        PermissionInstructionStep(
                            number: "3",
                            title: "Enable Notifications",
                            description: "Turn on \"Allow Notifications\" and \"Critical Alerts\""
                        )
                    }
                    
                    // Buttons
                    VStack(spacing: 12) {
                        Button(action: onOpenSettings) {
                            HStack {
                                Image(systemName: "gear")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Open Settings")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button(action: onDismiss) {
                            Text("Cancel")
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

private struct PermissionInstructionStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 28, height: 28)
                
                Text(number)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
            
            Spacer()
        }
    }
}

#Preview {
    AlarmPermissionDeniedView(
        onOpenSettings: {},
        onDismiss: {}
    )
}