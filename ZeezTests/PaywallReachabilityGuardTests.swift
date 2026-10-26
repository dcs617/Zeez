import Foundation
import Testing

/// The paywall stays unreachable until its copy clears the claims contract.
///
/// `SubscriptionView` sells `PremiumFeature`s by their descriptions — "Personalized
/// recommendations and coaching", "Real-time heart rate monitoring and advanced analytics",
/// "Detailed reports on how your environment affects sleep" — and none of those capabilities
/// exists. The last is also a causal claim `SLEEP_METRICS_CLAIMS_AND_VALIDATION.md` prohibits.
/// No screen opened it until reconnecting Trends would have, through three "Upgrade to
/// Premium" cards that a developer flag hid rather than an entitlement, so a subscriber would
/// have kept seeing them and unlocking showed nothing. See `FUTURE_IMPROVEMENTS.md`.
///
/// Giving the paywall an entry point is a product decision: review its copy first, then
/// change this guard on purpose.
struct PaywallReachabilityGuardTests {

    /// The paywall itself, and the gate that would present it (which has no callers).
    private static let definingFiles = [
        "Zeez/Views/SubscriptionView.swift",
        "Zeez/Commerce/PremiumFeatureGating.swift",
    ]

    /// Every way into `SubscriptionView`: directly, or through the gate.
    private static let entryPoints = [
        "SubscriptionView(",
        ".requiresPremium(",
        "PremiumGate(",
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
        let paths = try appSources().map(\.path)
        #expect(paths.count > 20)
        for path in Self.definingFiles {
            #expect(paths.contains(path), "\(path) moved; update this guard")
        }
    }

    @Test("No screen presents the paywall")
    func noScreenPresentsThePaywall() throws {
        for (path, contents) in try appSources() where !Self.definingFiles.contains(path) {
            for entryPoint in Self.entryPoints {
                let opensPaywall = contents.contains(entryPoint)
                #expect(
                    !opensPaywall,
                    "\(path) uses \(entryPoint), which opens SubscriptionView. Its feature list sells capabilities that do not exist; review it against the claims contract before giving it an entry point."
                )
            }
        }
    }
}
