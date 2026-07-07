import Testing
import Foundation

/// Regression guard for the second-audit A1 finding: the heart-rate screen once
/// fabricated an "HRV" timeline with `Double.random` and graded it as personal
/// cardiovascular "quality" — a Tier-3+ claim prohibited by
/// `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md` (rules 4 and 9).
///
/// These tests scan the heart-rate view sources at test time (located relative to
/// `#filePath`, so they run in CI where tests build from the same checkout) and fail
/// if HRV synthesis or randomized chart data ever returns to that surface.
struct HeartRateClaimsGuardTests {

    private static let heartRateSourcePaths = [
        "Zeez/Views/HeartRateView.swift",
        "Zeez/Views/HeartRateView+Charts.swift",
        "Zeez/Views/HeartRateView+Helpers.swift",
        "Zeez/Views/HeartRate",
    ]

    private static var repoRoot: URL {
        // ZeezTests/HeartRateClaimsGuardTests.swift → repo root is one level up.
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func heartRateSources() throws -> [(path: String, contents: String)] {
        var sources: [(String, String)] = []
        let fm = FileManager.default
        for relative in Self.heartRateSourcePaths {
            let url = Self.repoRoot.appendingPathComponent(relative)
            var isDirectory: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                let files = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "swift" }
                for file in files {
                    sources.append((relative + "/" + file.lastPathComponent,
                                    try String(contentsOf: file, encoding: .utf8)))
                }
            } else {
                sources.append((relative, try String(contentsOf: url, encoding: .utf8)))
            }
        }
        return sources
    }

    @Test("Heart-rate sources exist and are scannable")
    func sourcesAreFound() throws {
        let sources = try heartRateSources()
        #expect(sources.count >= 3, "Expected the heart-rate view sources at their audited paths; if they moved, update heartRateSourcePaths so this guard keeps protecting them")
    }

    @Test("Heart-rate screen never synthesizes randomized chart data")
    func noRandomizedChartData() throws {
        for (path, contents) in try heartRateSources() {
            #expect(!contents.contains(".random("), "\(path) generates random values; the A1 audit finding prohibits fabricated chart points on the heart-rate surface")
        }
    }

    @Test("HRV synthesis and quality grading stay deleted")
    func noHRVSynthesisOrQualityGrading() throws {
        for (path, contents) in try heartRateSources() {
            #expect(!contents.contains("calculateHRV"), "\(path) reintroduces calculateHRV; averaged heart-rate samples are not beat-to-beat intervals and must not be presented as HRV")
            #expect(!contents.contains("HRVQuality"), "\(path) reintroduces HRV quality grading; poor/fair/good/excellent is an unvalidated Tier-3+ health judgment")
            #expect(!contents.contains("RMSSD"), "\(path) reintroduces RMSSD computation from averaged samples")
        }
    }
}
