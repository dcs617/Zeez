import Foundation
import UserNotifications
import SwiftUI
import os.log

/// Manages alarm notification permissions with user-friendly onboarding
class AlarmPermissionManager: ObservableObject {
    static let shared = AlarmPermissionManager()
    
    @Published var showPermissionExplainer = false
    @Published var currentAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let hasShownExplainerKey = "hasShownAlarmPermissionExplainer"
    private var permissionCompletion: ((Bool) -> Void)?
    
    private init() {
        checkCurrentStatus()
    }
    
    /// Check if we should show the permission explainer on first launch
    func checkIfShouldShowExplainer() {
        // Only show if we haven't shown it before and permissions aren't determined
        let hasShownBefore = UserDefaults.standard.bool(forKey: hasShownExplainerKey)
        
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                if !hasShownBefore && settings.authorizationStatus == .notDetermined {
                    self?.showPermissionExplainer = true
                    ZeezLogger.info(ZeezLogger.alarm, "📱 Showing alarm permission explainer")
                } else if settings.authorizationStatus == .notDetermined {
                    // If we've shown explainer before but still not determined, request directly
                    self?.requestPermissions()
                }
            }
        }
    }
    
    /// Request permissions with user-friendly flow
    func requestPermissionsWithExplainer(completion: @escaping (Bool) -> Void = { _ in }) {
        permissionCompletion = completion
        
        let hasShownBefore = UserDefaults.standard.bool(forKey: hasShownExplainerKey)
        
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .notDetermined && !hasShownBefore {
                    self?.showPermissionExplainer = true
                } else {
                    self?.requestPermissions()
                }
            }
        }
    }
    
    /// Handle user allowing from explainer
    func handleExplainerAllow() {
        UserDefaults.standard.set(true, forKey: hasShownExplainerKey)
        showPermissionExplainer = false
        requestPermissions()
    }
    
    /// Handle user dismissing explainer
    func handleExplainerDismiss() {
        UserDefaults.standard.set(true, forKey: hasShownExplainerKey)
        showPermissionExplainer = false
        permissionCompletion?(false)
        permissionCompletion = nil
    }
    
    /// Request the actual system permissions
    private func requestPermissions() {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .criticalAlert]
        
        UNUserNotificationCenter.current().requestAuthorization(options: options) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.currentAuthorizationStatus = granted ? .authorized : .denied
                
                if let error = error {
                    ZeezLogger.error(ZeezLogger.alarm, "Notification authorization error", error: error)
                }
                
                ZeezLogger.info(ZeezLogger.alarm, "📱 Notification authorization granted: \(granted)")
                
                self?.permissionCompletion?(granted)
                self?.permissionCompletion = nil
            }
        }
    }
    
    /// Check current authorization status
    private func checkCurrentStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.currentAuthorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    /// Check if permissions are granted
    var isAuthorized: Bool {
        return currentAuthorizationStatus == .authorized
    }
    
    /// Check if permissions were denied
    var isDenied: Bool {
        return currentAuthorizationStatus == .denied
    }
    
    /// Show settings app for denied permissions
    func openSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl)
                ZeezLogger.info(ZeezLogger.alarm, "🔧 Opened Settings app for notification permissions")
            }
        }
    }
}