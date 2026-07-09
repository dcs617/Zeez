import Foundation
import os.log

/// Structured logging for the watch target, mirroring `ZeezLogger`'s shape.
///
/// `ZeezLogger` lives in `Zeez/Infrastructure/` and is compiled into the iOS target only.
/// The obvious place to share one logger — the repo-root `Shared/` folder — is the wrong
/// place: that folder is a synchronized group compiled into **both** targets, and it is
/// deliberately kept free of platform imports so its message and model types stay portable.
/// Hence a small parallel wrapper rather than a shared one.
///
/// Conventions match `ZeezLogger` exactly, so the two read alike in a sysdiagnose:
/// `debug` is stripped from release builds, and `info`/`error` mark interpolations
/// `.public` because os_log otherwise redacts non-literals to `<private>` in release —
/// which makes a TestFlight sysdiagnose useless. Keep health values and personal data out
/// of these messages.
enum WatchLogger {

    // MARK: - Log Categories

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.zeez.watch"

    /// Phone↔watch session lifecycle, reachability, and message handling.
    static let connectivity = Logger(subsystem: subsystem, category: "Connectivity")

    /// Haptic wake patterns.
    static let haptics = Logger(subsystem: subsystem, category: "Haptics")

    // MARK: - Convenience Methods

    /// Log debug information — compiled out of release builds.
    static func debug(
        _ logger: Logger,
        _ message: String,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        logger.debug("[\(fileName):\(line)] \(function): \(message)")
        #endif
    }

    /// Log informational messages.
    static func info(_ logger: Logger, _ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    /// Log error conditions.
    static func error(_ logger: Logger, _ message: String, error: Error? = nil) {
        if let error = error {
            logger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
        } else {
            logger.error("\(message, privacy: .public)")
        }
    }
}
