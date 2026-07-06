import SwiftUI
import AVFoundation

struct AlarmSoundPickerView: View {
    @Binding var selectedSound: String
    @Environment(\.dismiss) private var dismiss
    
    @State private var sounds = AlarmSounds.getAllSounds()
    @State private var isPlaying = false
    @State private var currentlyPlayingSound: String?
    
    var body: some View {
        NavigationView {
            List {
                Section("Built-in Sounds") {
                    ForEach(sounds.filter { $0.isBuiltIn }) { sound in
                        SoundRow(
                            sound: sound,
                            isSelected: selectedSound == sound.id,
                            isPlaying: currentlyPlayingSound == sound.id,
                            onSelect: { selectSound(sound) },
                            onPreview: { previewSound(sound) }
                        )
                    }
                }
                
                let customSounds = sounds.filter { !$0.isBuiltIn }
                if !customSounds.isEmpty {
                    Section("Custom Sounds") {
                        ForEach(customSounds) { sound in
                            SoundRow(
                                sound: sound,
                                isSelected: selectedSound == sound.id,
                                isPlaying: currentlyPlayingSound == sound.id,
                                onSelect: { selectSound(sound) },
                                onPreview: { previewSound(sound) }
                            )
                        }
                    }
                }
                
                Section("Add Custom Sounds") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 Pro Tip")
                            .font(.headline)
                        
                        Text("Add your own alarm sounds by adding audio files to your music library, then import them through the Files app.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Import from Files") {
                            // TODO: Implement custom sound import
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Alarm Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func selectSound(_ sound: AlarmSoundOption) {
        selectedSound = sound.id
        dismiss()
    }
    
    private func previewSound(_ sound: AlarmSoundOption) {
        guard !isPlaying else { return }
        
        isPlaying = true
        currentlyPlayingSound = sound.id
        
        AlarmSounds.previewSound(sound) {
            DispatchQueue.main.async {
                isPlaying = false
                currentlyPlayingSound = nil
            }
        }
    }
}

struct SoundRow: View {
    let sound: AlarmSoundOption
    let isSelected: Bool
    let isPlaying: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(sound.name)
                    .font(.body)
                
                if !sound.isBuiltIn {
                    Text("Custom")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onPreview) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .disabled(isPlaying && !isPlaying)
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                    .font(.body.weight(.semibold))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(sound.name) alarm sound")
        .accessibilityHint(isSelected ? "Currently selected" : "Tap to select this alarm sound")
        .accessibilityAction(named: "Preview") {
            onPreview()
        }
    }
}

#Preview {
    AlarmSoundPickerView(selectedSound: .constant("Alarm_Classic.caf"))
}