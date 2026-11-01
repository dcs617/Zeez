import Foundation
import Combine
import UserNotifications
import os.log

/// When a recording ends because an alarm is about to ring (decision 2026-10-29).
///
/// The recording lets go of the audio session a few seconds before the alarm, so the alarm
/// rings exactly as it does without a recording: the notification, its sound and its follow-up
/// chain are the paths `DEVICE_TEST_RUN.md` T5 checks, untouched. Whether iOS plays a
/// notification at full level while an app records in the background is not something a
/// recording should find out at 7 a.m. Mains and snoozes count (`AlarmHealth.PendingRequest
/// .isRing`, the same rule as the alarm health card); follow-ups only repeat a ring.
enum RecordingAlarmBoundary {
    /// How long before the ring the recording ends.
    static let lead: TimeInterval = 5

    /// The end time for a recording running at `now`, or `nil` when no alarm is pending.
    static func endTime(pending: [AlarmHealth.PendingRequest], now: Date) -> Date? {
        guard let ring = pending
            .filter(\.isRing)
            .compactMap(\.nextFireDate)
            .filter({ $0 > now })
            .min() else { return nil }
        return max(now, ring.addingTimeInterval(-lead))
    }
}

/// The live recording: starts and ends sessions through `SleepSessionManager`, and ends a
/// running one just before the next alarm (`RecordingAlarmBoundary`). Main thread only.
///
/// A recording needs the microphone (decision 2026-11-01), so Start asks first: when access
/// is refused, nothing starts and the alert offers Settings. A recording that cannot start
/// for any other reason alerts too (decision 4, 2026-10-29).
final class SleepRecordingController: ObservableObject {
    static let shared = SleepRecordingController()

    @Published private(set) var activeSession: SleepSession?
    /// When the running recording will end for the next alarm, if one is pending.
    @Published private(set) var alarmEndTime: Date?

    private let manager: SleepSessionManager
    private let center: AlarmNotificationScheduling
    private let microphone: MicrophonePermission
    private let errors: ErrorManager
    private let now: () -> Date
    private var alarmTimer: Timer?

    /// Tests inject an in-memory manager, fakes for the notification center and the
    /// microphone, their own error manager, and a clock.
    init(manager: SleepSessionManager = .shared,
         notificationCenter: AlarmNotificationScheduling = UNUserNotificationCenter.current(),
         microphone: MicrophonePermission = LiveMicrophonePermission(),
         errors: ErrorManager = .shared,
         now: @escaping () -> Date = Date.init) {
        self.manager = manager
        self.center = notificationCenter
        self.microphone = microphone
        self.errors = errors
        self.now = now
    }

    func start(completion: @escaping (Result<SleepSession, Error>) -> Void) {
        microphone.request { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    ZeezLogger.info(ZeezLogger.sleepTracking, "Recording not started: no microphone access")
                    self.errors.report(.microphonePermissionDenied)
                    completion(.failure(AppError.microphonePermissionDenied))
                    return
                }
                self.manager.startSession { result in
                    switch result {
                    case .success(let session):
                        self.activeSession = session
                        self.refreshAlarmBoundary()
                    case .failure(let error):
                        let denied = (error as? AppError) == .microphonePermissionDenied
                        self.errors.report(denied ? .microphonePermissionDenied : .sleepSessionCreationFailed)
                    }
                    completion(result)
                }
            }
        }
    }

    func end(at endTime: Date? = nil, completion: @escaping (Result<SessionEndOutcome, Error>) -> Void) {
        guard let session = activeSession else { return }
        alarmTimer?.invalidate()
        alarmTimer = nil
        manager.endSession(session, at: endTime ?? now()) { [weak self] result in
            if case .success = result {
                self?.activeSession = nil
                self?.alarmEndTime = nil
            }
            completion(result)
        }
    }

    /// Reads the pending alarms and schedules the end before the next one. Run at the start of
    /// a recording and whenever the alarms may have changed.
    func refreshAlarmBoundary(completion: (() -> Void)? = nil) {
        center.getPendingNotificationRequests { [weak self] requests in
            let pending = requests.map(AlarmHealth.PendingRequest.init)
            DispatchQueue.main.async {
                guard let self, self.activeSession != nil else {
                    completion?()
                    return
                }
                let end = RecordingAlarmBoundary.endTime(pending: pending, now: self.now())
                self.alarmEndTime = end
                self.scheduleAlarmTimer(at: end)
                completion?()
            }
        }
    }

    /// The boundary has come. The recording ends there, not later, even when the timer ran
    /// late: anything after it is the alarm.
    func endForAlarm(completion: @escaping (Result<SessionEndOutcome, Error>) -> Void = { _ in }) {
        guard activeSession != nil else { return }
        let endTime = min(now(), alarmEndTime ?? now())
        ZeezLogger.info(ZeezLogger.sleepTracking, "Recording ends for the alarm")
        end(at: endTime) { [errors] result in
            if case .failure(let error) = result {
                ZeezLogger.error(ZeezLogger.sleepTracking, "Recording did not end for the alarm", error: error)
                errors.report(.sleepSessionUpdateFailed)
            }
            completion(result)
        }
    }

    private func scheduleAlarmTimer(at date: Date?) {
        alarmTimer?.invalidate()
        alarmTimer = nil
        guard let date else { return }
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
            self?.endForAlarm()
        }
        RunLoop.main.add(timer, forMode: .common)
        alarmTimer = timer
    }
}
