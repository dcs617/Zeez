import Testing
import Foundation

/// Regression guard for the second-audit B7 finding. `DebtSeverity` graded a user's
/// "sleep debt" as minimal/moderate/significant/severe, attached health-risk impacts
/// ("weakened immune system", "cardiovascular strain") and told severe users to
/// "consult a healthcare professional"; `SleepDebtMetrics.recoveryPlan` and
/// `RecommendationsView` presented a "Recovery Timeline".
///
/// `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md` puts medical sleep debt, recovery/readiness,
/// health-risk conclusions and treatment advice in Tier 4 (rule 3, matrix row
/// "Medical / clinical conclusions"). A user-selected goal is not a determination of
/// physiological need, so the product says "sleep goal shortfall".
///
/// The Learn tree is exempt: it teaches sleep debt as a published concept (NHLBI) rather
/// than reporting the user's own, and says so on screen.
struct ClinicalVocabularyGuardTests {

    /// Phrases that must not appear outside the educational Learn tree.
    private static let prohibitedPhrases = [
        "sleep debt",
        "recovery plan",
        "recovery timeline",
        "recovery period",
        "healthcare professional",
        "sleep specialist",
        "medical advice",
        "time to recover",
    ]

    /// Trees whose "recovery" is about Core Data stores and errors, not the user's health.
    private static let exemptDirectories = [
        "Zeez/Learn",
        "Zeez/CoreData",
        "Zeez/Infrastructure",
        "Zeez/Documentation",
        "Zeez/Onboarding",
    ]

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func scannableSources() throws -> [(path: String, contents: String)] {
        let fm = FileManager.default
        let root = Self.repoRoot.appendingPathComponent("Zeez")
        guard let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }

        var sources: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let relative = url.path.replacingOccurrences(of: Self.repoRoot.path + "/", with: "")
            guard !Self.exemptDirectories.contains(where: { relative.hasPrefix($0 + "/") }) else {
                continue
            }
            sources.append((relative, try String(contentsOf: url, encoding: .utf8)))
        }
        return sources
    }

    @Test("Sources are found, so this guard is actually scanning something")
    func sourcesAreFound() throws {
        #expect(try scannableSources().count > 20)
    }

    @Test("Prohibited clinical vocabulary stays out of non-educational surfaces")
    func noProhibitedClinicalVocabulary() throws {
        for (path, contents) in try scannableSources() {
            // This test file's own phrase list would otherwise trip the scan.
            let haystack = contents.lowercased()
            for phrase in Self.prohibitedPhrases {
                #expect(
                    !haystack.contains(phrase),
                    "\(path) contains \"\(phrase)\". A user-selected goal is not medical sleep debt or a recovery need — use goal-shortfall wording (claims rule 3)."
                )
            }
        }
    }

    @Test("The graded debt-severity types stay deleted")
    func debtSeverityTypesStayDeleted() throws {
        for (path, contents) in try scannableSources() {
            #expect(!contents.contains("DebtSeverity"), "\(path) reintroduces DebtSeverity, which graded sleep debt and attached health-risk conclusions")
            #expect(!contents.contains("RecoveryPlan"), "\(path) reintroduces RecoveryPlan")
            #expect(!contents.contains("SleepDebtMetrics"), "\(path) reintroduces SleepDebtMetrics")
        }
    }

    /// C2 deleted `SleepRecommendationSystem` for claims reasons, not merely because it was
    /// unreachable. `AgeGroup.recommendedSleepRange` returned a physiological sleep-need range
    /// and `ActivityLevel.sleepAdjustment` added up to 1.5 h for "athletic" — determining how
    /// much sleep a person *needs* is a Tier-4 clinical conclusion, and the inputs it required
    /// (age, activity level) are data Zeez has never collected. See `PARKED_CAPABILITIES.md` §5.
    @Test("The sleep-need recommendation engine stays deleted")
    func recommendationEngineStaysDeleted() throws {
        for (path, contents) in try scannableSources() {
            #expect(!contents.contains("SleepRecommendationSystem"), "\(path) reintroduces SleepRecommendationSystem; prescribing a sleep-need range from age and activity is a Tier-4 conclusion, and the app collects neither input")
            #expect(!contents.contains("recommendedSleepRange"), "\(path) reintroduces recommendedSleepRange; a user-selected goal is not a determination of physiological need")
            #expect(!contents.contains("sleepAdjustment"), "\(path) reintroduces sleepAdjustment, which added sleep-need hours from activity level")
        }
    }
}
