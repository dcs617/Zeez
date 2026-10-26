import Foundation
import Testing

/// Claims rule 10: a score never loses its experimental label "when sent to watchOS, rendered in a
/// chart, or described through accessibility output". Swift Charts reads a series' plottable name
/// to VoiceOver for every data point and in Audio Graphs, so a series named "Quality" announces
/// each Experimental Zeez Estimate as a quality value.
struct ExperimentalLabelGuardTests {

    /// Series names that present the estimate as something it is not.
    private static let unlabeledSeriesNames = [
        ".value(\"Quality\"",
        ".value(\"Sleep Quality\"",
        ".value(\"Score\"",
    ]

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

    @Test("Sources are found, so this guard is actually scanning something")
    func sourcesAreFound() throws {
        #expect(try appSources().count > 20)
    }

    @Test("No chart names an estimate series without its experimental label")
    func estimateSeriesKeepTheirLabel() throws {
        for (path, contents) in try appSources() {
            for name in Self.unlabeledSeriesNames {
                let unlabeled = contents.contains(name)
                #expect(!unlabeled, "\(path) plots a series as \(name)). Name an estimate series \"Experimental Zeez estimate\" (claims rule 10).")
            }
        }
    }
}
