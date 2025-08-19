import Foundation
import UserNotifications
import AVFoundation

/// Manages alarm sounds including built-in iOS sounds and custom user sounds
struct AlarmSounds {
    
    /// Available built-in alarm sounds from iOS
    static let builtInSounds: [AlarmSoundOption] = [
        AlarmSoundOption(id: "default", name: "Default", isBuiltIn: true),
        AlarmSoundOption(id: "radar", name: "Radar", isBuiltIn: true),
        AlarmSoundOption(id: "apex", name: "Apex", isBuiltIn: true),
        AlarmSoundOption(id: "beacon", name: "Beacon", isBuiltIn: true),
        AlarmSoundOption(id: "bulletin", name: "Bulletin", isBuiltIn: true),
        AlarmSoundOption(id: "by_the_seaside", name: "By The Seaside", isBuiltIn: true),
        AlarmSoundOption(id: "chimes", name: "Chimes", isBuiltIn: true),
        AlarmSoundOption(id: "circuit", name: "Circuit", isBuiltIn: true),
        AlarmSoundOption(id: "cosmic", name: "Cosmic", isBuiltIn: true),
        AlarmSoundOption(id: "hillside", name: "Hillside", isBuiltIn: true),
        AlarmSoundOption(id: "night_owl", name: "Night Owl", isBuiltIn: true),
        AlarmSoundOption(id: "opening", name: "Opening", isBuiltIn: true),
        AlarmSoundOption(id: "presto", name: "Presto", isBuiltIn: true),
        AlarmSoundOption(id: "sencha", name: "Sencha", isBuiltIn: true),
        AlarmSoundOption(id: "silk", name: "Silk", isBuiltIn: true),
        AlarmSoundOption(id: "slow_rise", name: "Slow Rise", isBuiltIn: true),
        AlarmSoundOption(id: "summit", name: "Summit", isBuiltIn: true),
        AlarmSoundOption(id: "uplift", name: "Uplift", isBuiltIn: true)
    ]
    
    /// Get all available alarm sounds (built-in + custom)
    static func getAllSounds() -> [AlarmSoundOption] {
        var allSounds = builtInSounds
        allSounds.append(contentsOf: getCustomSounds())
        return allSounds
    }
    
    /// Get custom user sounds from the app bundle
    static func getCustomSounds() -> [AlarmSoundOption] {
        var customSounds: [AlarmSoundOption] = []
        
        // Check for custom sounds in the app bundle
        if let soundsPath = Bundle.main.path(forResource: "CustomAlarmSounds", ofType: "bundle"),
           let soundsBundle = Bundle(path: soundsPath) {
            
            let soundExtensions = ["m4a", "mp3", "wav", "aiff", "caf"]
            
            for ext in soundExtensions {
                let soundPaths = soundsBundle.paths(forResourcesOfType: ext, inDirectory: nil)
                
                for path in soundPaths {
                    let fileName = URL(fileURLWithPath: path).lastPathComponent
                    let soundName = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                    let displayName = soundName.replacingOccurrences(of: "_", with: " ").capitalized
                    
                    customSounds.append(AlarmSoundOption(
                        id: fileName,
                        name: displayName,
                        isBuiltIn: false
                    ))
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
                // For built-in sounds, we'll use a short preview
                // Note: Built-in iOS alarm sounds aren't directly accessible for preview
                // This would need to be implemented with custom sound files
                completion()
                return
            } else {
                // Custom sound preview
                if let soundURL = Bundle.main.url(forResource: soundOption.id, withExtension: nil) {
                    player = try AVAudioPlayer(contentsOf: soundURL)
                    player?.volume = 0.5
                    player?.play()
                    
                    // Stop after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        player?.stop()
                        completion()
                    }
                } else {
                    completion()
                }
            }
        } catch {
            print("Error playing sound preview: \(error)")
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