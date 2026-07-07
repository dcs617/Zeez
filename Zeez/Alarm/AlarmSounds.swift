import Foundation
import UserNotifications
import AVFoundation

/// Manages alarm sounds including built-in iOS sounds and custom user sounds
struct AlarmSounds {
    
    /// Available system alarm sounds (only default works in local notifications)
    static let builtInSounds: [AlarmSoundOption] = [
        // No built-in sounds - Classic Alarm is now the default
    ]
    
    /// Get all available alarm sounds (built-in + custom)
    static func getAllSounds() -> [AlarmSoundOption] {
        var allSounds = builtInSounds
        allSounds.append(contentsOf: getCustomSounds())
        return allSounds
    }
    
    /// Custom Zeez alarm sounds (bundled with the app)
    static let customZeezSounds: [AlarmSoundOption] = [
        AlarmSoundOption(id: "Alarm_Classic.caf", name: "Classic Alarm", isBuiltIn: false),
        AlarmSoundOption(id: "Alarm_Honk.caf", name: "Honk", isBuiltIn: false),
        AlarmSoundOption(id: "Alarm_Horn.caf", name: "Horn", isBuiltIn: false)
    ]
    
    /// Get custom user sounds from the app bundle
    static func getCustomSounds() -> [AlarmSoundOption] {
        var customSounds: [AlarmSoundOption] = []
        
        // Add our bundled Zeez sounds first
        customSounds.append(contentsOf: customZeezSounds)
        
        // Check for sounds in Resources/AlarmSounds/ directory
        let soundExtensions = ["caf", "aiff", "wav", "m4a", "mp3"]
        
        for ext in soundExtensions {
            if let soundURLs = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: "AlarmSounds") {
                for url in soundURLs {
                    let fileName = url.lastPathComponent
                    let soundName = url.deletingPathExtension().lastPathComponent
                    let displayName = soundName.replacingOccurrences(of: "_", with: " ").capitalized
                    
                    // Skip if we already added this as a Zeez sound
                    if !customZeezSounds.contains(where: { $0.id == fileName }) {
                        customSounds.append(AlarmSoundOption(
                            id: fileName,
                            name: displayName,
                            isBuiltIn: false
                        ))
                    }
                }
            }
        }
        
        // Also check main bundle root for any additional sounds
        for ext in soundExtensions {
            if let soundURLs = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                for url in soundURLs {
                    let fileName = url.lastPathComponent
                    let soundName = url.deletingPathExtension().lastPathComponent
                    let displayName = soundName.replacingOccurrences(of: "_", with: " ").capitalized
                    
                    // Skip if already added
                    if !customSounds.contains(where: { $0.id == fileName }) {
                        customSounds.append(AlarmSoundOption(
                            id: fileName,
                            name: displayName,
                            isBuiltIn: false
                        ))
                    }
                }
            }
        }
        
        return customSounds
    }
    
    /// Preview a sound (play it for a few seconds)
    static func previewSound(_ soundOption: AlarmSoundOption, completion: @escaping () -> Void) {
        var player: AVAudioPlayer?
        
        do {
            // Configure audio session for playback
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            if soundOption.isBuiltIn {
                // For built-in default sound, play the system alert sound
                AudioServicesPlaySystemSound(SystemSoundID(1005)) // System alert sound
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    completion()
                }
                return
            } else {
                // Custom sound preview - try multiple locations
                var soundURL: URL?
                
                // First try in AlarmSounds subdirectory
                soundURL = Bundle.main.url(forResource: soundOption.id, withExtension: nil, subdirectory: "AlarmSounds")
                
                // If not found, try removing the extension and searching
                if soundURL == nil {
                    let nameWithoutExt = URL(fileURLWithPath: soundOption.id).deletingPathExtension().lastPathComponent
                    soundURL = Bundle.main.url(forResource: nameWithoutExt, withExtension: "caf", subdirectory: "AlarmSounds")
                }
                
                // Fallback to main bundle
                if soundURL == nil {
                    soundURL = Bundle.main.url(forResource: soundOption.id, withExtension: nil)
                }
                
                if let url = soundURL {
                    player = try AVAudioPlayer(contentsOf: url)
                    player?.volume = 0.5
                    player?.play()
                    
                    // Stop after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        player?.stop()
                        completion()
                    }
                } else {
                    ZeezLogger.error(ZeezLogger.alarm, "Could not find sound file: \(soundOption.id)")
                    completion()
                }
            }
        } catch {
            ZeezLogger.error(ZeezLogger.alarm, "Error playing sound preview", error: error)
            completion()
        }
    }
}

/// Represents an alarm sound option
struct AlarmSoundOption: Identifiable, Hashable {
    let id: String
    let name: String
    let isBuiltIn: Bool
}