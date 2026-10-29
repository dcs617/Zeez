import Foundation
import Testing

/// Only the alarm registers notification categories.
///
/// `setNotificationCategories` replaces the app's whole set. `AlarmNotificationRegistrar`
/// registers `ZEEZ_ALARM` (Snooze, Continue and Stop) at launch, and `LearnNotificationManager`'s
/// init used to register its own two categories the first time Learn reminders were toggled,
/// which dropped the alarm's actions until the next launch. Learn's actions never worked
/// either: their handler had no caller, and the app's only notification delegate is
/// `AlarmNotificationHandler`. A category added later goes into the registrar's one call.
struct NotificationCategoryGuardTests {

    private static let registrar = "Zeez/Alarm/AlarmNotificationRegistrar.swift"

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Swift sources compiled into the iOS app: `Zeez/` and the shared models.
    private func appSources() throws -> [(path: String, contents: String)] {
        var sources: [(String, String)] = []
        for folder in ["Zeez", "Shared"] {
            let root = Self.repoRoot.appendingPathComponent(folder)
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
                continue
            }
            for case let url as URL in walker where url.pathExtension == "swift" {
                let relative = url.path.replacingOccurrences(of: Self.repoRoot.path + "/", with: "")
                sources.append((relative, try String(contentsOf: url, encoding: .utf8)))
            }
        }
        return sources
    }

    /// Lines in `source` that call `setNotificationCategories`, ignoring comments.
    static func registrations(in source: String) -> [String] {
        source.components(separatedBy: .newlines).filter { line in
            let code = line.trimmingCharacters(in: .whitespaces)
            return !code.hasPrefix("//") && code.contains("setNotificationCategories(")
        }
    }

    @Test("The scan finds the registrar's call, so this guard is actually scanning something")
    func registrarIsFound() throws {
        let sources = try appSources()
        #expect(sources.count > 20)
        let registrar = try #require(sources.first { $0.path == Self.registrar }, "\(Self.registrar) moved; update this guard")
        #expect(Self.registrations(in: registrar.contents).count == 1)
    }

    @Test("No other file replaces the notification categories")
    func onlyTheRegistrarSetsCategories() throws {
        for (path, contents) in try appSources() where path != Self.registrar {
            let found = Self.registrations(in: contents)
            #expect(
                found.isEmpty,
                "\(path) calls setNotificationCategories, which replaces the whole set and drops the alarm's Snooze, Continue and Stop: \(found). Add the category to AlarmNotificationRegistrar.registerCategories instead."
            )
        }
    }
}
