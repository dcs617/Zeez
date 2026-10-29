import UIKit
import Combine

/// The charger suggestion on the recording screen (decision 2026-10-29).
///
/// A line of text, never an alert, and it never holds a recording back: a recording starts
/// whatever the battery says. It shows only on an unplugged phone, and the stronger line
/// below `lowLevel` names the alarm, because a phone that dies overnight cannot ring. Zeez's
/// overnight drain has not been measured, so the copy quotes no figure for it.
enum RecordingBatteryAdvice {
    /// At or below this level the message says the phone may not last until morning.
    static let lowLevel: Float = 0.30

    /// `nil` when charging, full, or unknown (the simulator reports `.unknown` and -1).
    static func message(state: UIDevice.BatteryState, level: Float) -> String? {
        guard state == .unplugged, level >= 0 else { return nil }
        if level <= lowLevel {
            let percent = Int((level * 100).rounded())
            return "Your battery is at \(percent)%. Plug in your phone so the recording and your alarm last until morning."
        }
        return "Recording all night uses battery. Plug in your phone if you can."
    }
}

/// Publishes `RecordingBatteryAdvice` for the device, updating when it is plugged in or the
/// level changes, so the line goes away as soon as the charger is connected.
final class RecordingBatteryAdviceMonitor: ObservableObject {
    @Published private(set) var message: String?

    private var observers: [NSObjectProtocol] = []

    init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()
        for name in [UIDevice.batteryStateDidChangeNotification, UIDevice.batteryLevelDidChangeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            })
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    private func refresh() {
        message = RecordingBatteryAdvice.message(state: UIDevice.current.batteryState,
                                                 level: UIDevice.current.batteryLevel)
    }
}
