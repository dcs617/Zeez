import Foundation
import Testing

/// Learning Paths shows no number it did not count.
///
/// The screen showed every user "Articles 12 Read", "Quizzes 8 Completed" and "Streak 5 Days",
/// a "Recommended Next" card promising "4 Articles · 2 Quizzes" above a "Start Path" button
/// that did nothing, and "Estimated completion: 2-3 hours" on every path. All of it was fixed
/// text. A number on these screens comes from the user's own data, or it is not shown.
struct LearningPathNumbersGuardTests {

    private static let files = [
        "Zeez/Learn/LearnPathNavigator.swift",
        "Zeez/Learn/LearnPathDetail.swift",
    ]

    /// A literal count passed as a displayed value, a literal count of content, and the fixed
    /// completion estimate.
    private static let patterns: [NSRegularExpression] = [
        #"value:\s*"\d+""#,
        #""\d+ (Articles|Quizzes)""#,
        #"Estimated completion"#,
    ].map { try! NSRegularExpression(pattern: $0) }

    /// The fixed numbers in `source`, as the text that matched.
    static func fixedNumbers(in source: String) -> [String] {
        let range = NSRange(source.startIndex..., in: source)
        return patterns.flatMap { pattern in
            pattern.matches(in: source, range: range).compactMap { match in
                Range(match.range, in: source).map { String(source[$0]) }
            }
        }
    }

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test("The scan recognizes each kind of fixed number, and skips counted ones")
    func scanRecognizesFixedNumbers() {
        #expect(Self.fixedNumbers(in: #"StatCard(title: "Articles", value: "12", subtitle: "Read")"#).count == 1)
        #expect(Self.fixedNumbers(in: #"Label("4 Articles", systemImage: "doc.text")"#).count == 1)
        #expect(Self.fixedNumbers(in: #"Text("Estimated completion: 2-3 hours")"#).count == 1)
        #expect(Self.fixedNumbers(in: #"StatCard(title: "Articles", value: "\(readCount)")"#).isEmpty)
        #expect(Self.fixedNumbers(in: #"Text("\(Int(progress * 100))%")"#).isEmpty)
    }

    @Test("Learning Paths shows no fixed counts or estimates")
    func noFixedNumbers() throws {
        for file in Self.files {
            let source = try String(contentsOf: Self.repoRoot.appendingPathComponent(file), encoding: .utf8)
            let found = Self.fixedNumbers(in: source)
            #expect(
                found.isEmpty,
                "\(file) shows a number nobody counted: \(found). Compute it from the user's data or leave it out."
            )
        }
    }
}
