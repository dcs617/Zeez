import CoreData

/// `SleepNote` holds two kinds of note: Learn's notes, written about articles, and notes
/// added to a recording (2026-11-01), which belong to their session. Learn's lists show only
/// their own (`SleepNoteScopeTests` pins every Learn fetch).
extension SleepNote {
    /// The category of a note added during a recording.
    static let recordingCategory = "recording"

    /// Learn's notes: every note not attached to a recorded night.
    static var learnNotesPredicate: NSPredicate {
        NSPredicate(format: "session == nil")
    }
}
