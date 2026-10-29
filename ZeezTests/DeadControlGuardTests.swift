import Foundation
import Testing

/// No button in the app does nothing when tapped.
///
/// The alarm sound picker offered "Import from Files" under a tip describing an import the app
/// never had; the button's action was `// TODO: Implement custom sound import`. A control that
/// does nothing breaks a promise to the user, and App Review rejects incomplete features
/// (guideline 2.1). This scans for a `Button` whose action is empty or only comments. An
/// alert's `role: .cancel` button is exempt: the alert dismisses itself, so its empty action is
/// correct.
struct DeadControlGuardTests {

    /// Dead buttons that were already there when this guard was written (2026-10-27). They are
    /// tracked in `FUTURE_IMPROVEMENTS.md`, not fixed here. Lower a count when you fix one.
    private static let known: [String: Int] = [
        "Zeez/Learn/LearnPathNavigator.swift": 1,        // "Start Path"
        "Zeez/Views/DreamView.swift": 3,                 // play, pause, next; no screen opens it
    ]

    private static let comments = #"(?://[^\n]*\n\s*)*"#

    /// `Button("Title") { }`, `Button(action: {}) { … }` and `Button { } label: { … }`.
    private static let patterns: [NSRegularExpression] = [
        #"Button\((?:[^(){}"]|"[^"]*"|\([^()]*\))*\)\s*\{\s*"# + comments + #"\}"#,
        #"Button\((?:[^(){}"]|"[^"]*")*action:\s*\{\s*"# + comments + #"\}"#,
        #"Button\s*\{\s*"# + comments + #"\}\s*label:"#,
    ].map { try! NSRegularExpression(pattern: $0) }

    /// The dead buttons in `source`, as the text that matched.
    static func deadButtons(in source: String) -> [String] {
        let range = NSRange(source.startIndex..., in: source)
        return patterns.flatMap { pattern in
            pattern.matches(in: source, range: range).compactMap { match -> String? in
                guard let found = Range(match.range, in: source) else { return nil }
                let text = String(source[found])
                return text.contains("role: .cancel") ? nil : text
            }
        }
    }

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func appSources() throws -> [(path: String, contents: String)] {
        let root = Self.repoRoot.appendingPathComponent("Zeez")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        var sources: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let relative = url.path.replacingOccurrences(of: Self.repoRoot.path + "/", with: "")
            sources.append((relative, try String(contentsOf: url, encoding: .utf8)))
        }
        return sources
    }

    @Test("The scan finds a dead button in each form, and skips live and cancel buttons")
    func scanRecognizesDeadButtons() {
        #expect(Self.deadButtons(in: "Button(\"Import\") {\n    // TODO: later\n}").count == 1)
        #expect(Self.deadButtons(in: "Button(action: {}) { Text(\"Go\") }").count == 1)
        #expect(Self.deadButtons(in: "Button {\n} label: { Text(\"Go\") }").count == 1)
        #expect(Self.deadButtons(in: "Button(\"Import\") { importFile() }").isEmpty)
        #expect(Self.deadButtons(in: "Button(action: { go() }) { Text(\"Go\") }").isEmpty)
        #expect(Self.deadButtons(in: "Button(\"Cancel\", role: .cancel) { }").isEmpty)
    }

    @Test("Sources are found, so this guard is actually scanning something")
    func sourcesAreFound() throws {
        let paths = try appSources().map(\.path)
        #expect(paths.count > 20)
        for path in Self.known.keys {
            #expect(paths.contains(path), "\(path) moved or was deleted; update this guard")
        }
    }

    @Test("No button does nothing when tapped, beyond the known ones")
    func noNewDeadButtons() throws {
        for (path, contents) in try appSources() {
            let dead = Self.deadButtons(in: contents)
            let expected = Self.known[path] ?? 0
            #expect(
                dead.count == expected,
                "\(path) has \(dead.count) buttons that do nothing, expected \(expected): \(dead). Implement the action or remove the button; if you fixed a known one, lower its count."
            )
        }
    }
}
