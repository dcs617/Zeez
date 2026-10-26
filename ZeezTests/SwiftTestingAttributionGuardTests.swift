import Testing
import Foundation

/// Guards the rule in CLAUDE.md (Testing): assert outside Core Data closures.
///
/// Swift Testing finds the running test through a task-local value. A closure that runs
/// outside the test's task records its issues against no test: the console logs
/// `✘ Test «unknown» recorded an issue`, the test passes, and xcodebuild exits 0. Canaries
/// (2026-10-25, Xcode 26.6) showed that `await context.perform { }` does this on every
/// context, whatever the caller's isolation, and that `viewContext.performAndWait { }` does
/// it off the main actor, where it hops to the main queue. A `try #require` failing there
/// does not fail the test either. This suite fails on any assertion written:
///
/// - inside a `perform` closure;
/// - inside a `performAndWait` closure, or a test helper that runs its closure argument in
///   one (`withInMemoryContext`), unless the enclosing function or type is `@MainActor`;
/// - in a call, from inside either, to a test helper that itself asserts.
///
/// Reading source cannot tell a private context, whose `performAndWait` runs inline and
/// keeps the test, from the viewContext, so private contexts are held to the same rule. The
/// fix is always the same: return plain values from the closure and assert outside it.
///
/// The unit-tests CI job also fails on the console's «unknown» line
/// (`.github/scripts/check-swift-testing-attribution.sh`). That catches what this scan
/// cannot see, but only once the misplaced assertion actually fails.
///
/// Sources are located relative to `#filePath` so this runs in CI from the same checkout.
struct SwiftTestingAttributionGuardTests {

    private static var testsDirectory: URL {
        // ZeezTests/SwiftTestingAttributionGuardTests.swift → the ZeezTests directory.
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    }

    @Test("The scanner flags each shape that loses the running test, and nothing else")
    func scannerFlagsExactlyTheLosingShapes() {
        let report = AttributionScanner.scan([(name: "Fixture.swift", text: Self.fixture)])
        let flagged = Set(report.violations.map(\.line))
        let expected = Set(Self.fixture.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .filter { $0.element.hasSuffix("// flagged") }
            .map { $0.offset + 1 })

        #expect(expected.count == 9, "The fixture lost a // flagged marker")
        #expect(flagged == expected, "\(report.violations.map(\.description).joined(separator: "\n"))")
    }

    @Test("No assertion in ZeezTests runs where Swift Testing cannot see the running test")
    func testsAssertOutsideCoreDataClosures() throws {
        let files = try FileManager.default
            .contentsOfDirectory(at: Self.testsDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let sources = try files.map { url in
            (name: url.lastPathComponent, text: try String(contentsOf: url, encoding: .utf8))
        }
        let report = AttributionScanner.scan(sources)

        // A moved directory, or a scanner that stopped recognizing the suites, would
        // otherwise pass by finding nothing.
        #expect(report.files >= 40, "Scanned only \(report.files) files")
        #expect(report.assertions >= 500, "Found only \(report.assertions) assertions")
        #expect(report.coreDataClosures >= 40, "Found only \(report.coreDataClosures) Core Data closures")

        #expect(report.violations.isEmpty, """
            Return plain values from the closure and assert outside it (CLAUDE.md, Testing):
            \(report.violations.map(\.description).joined(separator: "\n"))
            """)
    }

    /// One case per canary shape. Lines ending `// flagged` must be reported; no other line may be.
    private static let fixture = """
        import Testing
        import CoreData

        private func withContext<T>(_ body: (NSManagedObjectContext) throws -> T) rethrows -> T {
            let context = PersistenceController(inMemory: true).container.viewContext
            return try context.performAndWait { try body(context) }
        }

        private func requireValue(_ value: Int?) throws -> Int {
            try #require(value)
        }

        struct Fixture {
            let context = PersistenceController(inMemory: true).container.viewContext

            @Test func viewContextOffTheMainActor() {
                context.performAndWait { #expect(Bool(false)) } // flagged
            }

            @Test @MainActor func viewContextOnTheMainActor() {
                context.performAndWait { #expect(Bool(false)) }
            }

            @Test func awaitPerform() async {
                await context.perform { #expect(Bool(false)) } // flagged
            }

            @MainActor
            @Test func awaitPerformOnTheMainActor() async throws {
                try await context.perform {
                    _ = try #require(nil as Int?) // flagged
                }
            }

            @Test func performWithArguments() async {
                await context.perform(schedule: .immediate) { Issue.record("x") } // flagged
            }

            @Test func wrapperHelper() throws {
                try withContext { _ in #expect(Bool(false)) } // flagged
            }

            @Test func assertingHelperCalledInside() throws {
                try context.performAndWait { _ = try requireValue(nil) } // flagged
            }

            @Test func nestedClosure() {
                context.performAndWait {
                    [1].forEach { #expect($0 > 1) } // flagged
                }
            }

            @Test func privateContext() {
                let background = PersistenceController(inMemory: true).newBackgroundContext()
                background.performAndWait { #expect(Bool(false)) } // flagged
            }

            @Test func returnedThenAsserted() throws {
                let value = context.performAndWait { 1 }
                #expect(value == 1)
                let wrapped = try withContext { _ in 2 }
                #expect(wrapped == 2)
                _ = try requireValue(value)
                #expect(try #require(context.performAndWait { Optional(3) }) == 3)
            }

            @Test func otherClosures() async {
                [1].forEach { #expect($0 == 1) }
                await withCheckedContinuation { continuation in
                    #expect(Bool(true))
                    continuation.resume()
                }
            }

            @Test func commentsAndStrings() {
                // context.performAndWait { #expect(Bool(false)) }
                /* await context.perform { #expect(Bool(false)) } */
                let text = "context.performAndWait { #expect(Bool(false)) }"
                #expect(!text.isEmpty)
            }
        }

        @MainActor
        @Suite struct MainActorSuite {
            let context = PersistenceController(inMemory: true).container.viewContext

            @Test func viewContextInAMainActorSuite() {
                context.performAndWait { #expect(Bool(false)) }
            }

            @Test func awaitPerformInAMainActorSuite() async {
                await context.perform { #expect(Bool(false)) } // flagged
            }
        }
        """
}

/// A brace-level scan of Swift test sources. Not a parser: it blanks comments and string
/// literals, splits the rest into tokens, and tracks `{ }` scopes, which is enough for the
/// shapes the suites are written in.
private enum AttributionScanner {

    typealias Source = (name: String, text: String)

    struct Violation: CustomStringConvertible {
        let file: String
        let line: Int
        let message: String
        var description: String { "\(file):\(line): \(message)" }
    }

    struct Report {
        var files = 0
        var assertions = 0
        var coreDataClosures = 0
        var violations: [Violation] = []
    }

    static func scan(_ sources: [Source]) -> Report {
        let files = sources.map { (name: $0.name, tokens: tokens(in: code(of: $0.text))) }

        // Pass 1: which helpers assert, and which run their closure argument on a context's
        // queue. A file with no tests (AlarmTestSupport) shares its helpers with every file.
        var shared = Helpers()
        var local: [Helpers] = []
        for file in files {
            let helpers = Helpers(walk(file.tokens, wrappers: [:]).functions)
            local.append(helpers)
            if !file.tokens.contains(where: { $0.text == "@Test" }) { shared.merge(helpers) }
        }

        // Pass 2: every assertion, and every call to an asserting helper, in a Core Data closure.
        var report = Report()
        for (index, file) in files.enumerated() {
            var helpers = local[index]
            helpers.merge(shared)
            let walked = walk(file.tokens, wrappers: helpers.wrappers)
            report.files += 1
            report.assertions += walked.assertions
            report.coreDataClosures += walked.coreDataClosures
            for site in walked.sites {
                if let callee = site.callee, !helpers.asserting.contains(callee) { continue }
                let what = site.callee.map { "a call to \($0)(), which asserts," } ?? site.token
                if site.inPerform {
                    report.violations.append(Violation(file: file.name, line: site.line, message:
                        "\(what) runs inside a perform closure, which Swift Testing attributes to no test whatever the isolation"))
                } else if !site.onMainActor {
                    report.violations.append(Violation(file: file.name, line: site.line, message:
                        "\(what) runs inside a performAndWait closure off the main actor, which Swift Testing attributes to no test"))
                }
            }
        }
        return report
    }

    // MARK: - Scopes

    private struct Token {
        let text: String
        let line: Int
    }

    private struct Function {
        let name: String
        let isTest: Bool
        /// Takes a closure parameter that is handed an `NSManagedObjectContext`.
        let takesContextClosure: Bool
        var asserts = false
        /// nil: runs no Core Data closure; true: runs a `perform` one; false: `performAndWait` only.
        var runsCoreDataClosure: Bool?
    }

    private struct Helpers {
        var asserting: Set<String> = []
        /// Helper name → whether it runs its closure argument in `perform` (true) or `performAndWait`.
        var wrappers: [String: Bool] = [:]

        init() {}

        init(_ functions: [Function]) {
            for function in functions where !function.isTest {
                if function.asserts { asserting.insert(function.name) }
                if function.takesContextClosure, let perform = function.runsCoreDataClosure {
                    wrappers[function.name] = perform
                }
            }
        }

        mutating func merge(_ other: Helpers) {
            asserting.formUnion(other.asserting)
            wrappers.merge(other.wrappers) { $0 || $1 }
        }
    }

    private enum Isolation { case mainActor, nonisolated, inherited }

    private enum Scope {
        case function(index: Int, isolation: Isolation)
        case type(isolation: Isolation)
        /// A closure that runs on a context's queue: `perform` (true) or `performAndWait` (false).
        case coreData(perform: Bool)
        case other
    }

    /// An assertion, or a call that might be to an asserting helper, inside a Core Data closure.
    private struct Site {
        let line: Int
        let token: String
        let callee: String?
        let inPerform: Bool
        let onMainActor: Bool
    }

    private static func walk(_ tokens: [Token], wrappers: [String: Bool])
        -> (functions: [Function], assertions: Int, coreDataClosures: Int, sites: [Site]) {
        var functions: [Function] = []
        var stack: [Scope] = []
        var assertions = 0
        var coreDataClosures = 0
        var sites: [Site] = []

        for (t, token) in tokens.enumerated() {
            if token.text == "{" {
                let scope = classify(tokens, brace: t, wrappers: wrappers, functions: &functions)
                if case let .coreData(perform) = scope {
                    coreDataClosures += 1
                    for case let .function(index, _) in stack {
                        functions[index].runsCoreDataClosure = perform || functions[index].runsCoreDataClosure == true
                    }
                }
                stack.append(scope)
                continue
            }
            if token.text == "}" {
                if !stack.isEmpty { stack.removeLast() }
                continue
            }

            let isAssertion = token.text == "#expect" || token.text == "#require"
                || (token.text == "Issue" && t + 2 < tokens.count
                    && tokens[t + 1].text == "." && tokens[t + 2].text == "record")
            if isAssertion {
                assertions += 1
                for case let .function(index, _) in stack { functions[index].asserts = true }
            }
            let isCall = !isAssertion && isName(token) && t + 1 < tokens.count && tokens[t + 1].text == "("
                && !(t > 0 && tokens[t - 1].text == "func") && isUnqualifiedOrOwnCall(tokens, t)
            guard isAssertion || isCall else { continue }

            var inCoreData = false
            var inPerform = false
            for case let .coreData(perform) in stack {
                inCoreData = true
                inPerform = inPerform || perform
            }
            guard inCoreData else { continue }
            sites.append(Site(line: token.line,
                              token: token.text == "Issue" ? "Issue.record" : token.text,
                              callee: isCall ? token.text : nil,
                              inPerform: inPerform,
                              onMainActor: isMainActor(stack)))
        }
        return (functions, assertions, coreDataClosures, sites)
    }

    private static let typeKeywords: Set<String> = ["struct", "class", "enum", "extension", "actor", "protocol"]
    private static let modifiers: Set<String> = [
        "private", "fileprivate", "internal", "public", "open", "static", "class", "final",
        "override", "mutating", "nonmutating", "nonisolated", "convenience", "required", "dynamic"
    ]

    private static func classify(_ tokens: [Token], brace t: Int, wrappers: [String: Bool],
                                 functions: inout [Function]) -> Scope {
        // The header is everything since the previous statement or scope boundary.
        var start = t
        while start > 0, !["{", "}", ";"].contains(tokens[start - 1].text) { start -= 1 }
        let header = start..<t

        if let keyword = header.last(where: { isFunctionKeyword(tokens, $0) }) {
            let words = declarationWords(tokens, before: keyword)
            let nameIndex = tokens[keyword].text == "func" ? keyword + 1 : keyword
            functions.append(Function(name: tokens[nameIndex].text,
                                      isTest: words.contains("@Test"),
                                      takesContextClosure: takesContextClosure(tokens, name: nameIndex, end: t)))
            return .function(index: functions.count - 1, isolation: isolation(words))
        }
        if let keyword = header.first(where: {
            typeKeywords.contains(tokens[$0].text) && $0 + 1 < t && isName(tokens[$0 + 1])
                && !($0 > 0 && tokens[$0 - 1].text == ".")
        }) {
            return .type(isolation: isolation(declarationWords(tokens, before: keyword)))
        }

        // A trailing closure: `callee {`, `callee(…) {`, or a first argument, `callee({`.
        var j = t - 1
        if j >= 0, tokens[j].text == ")", let open = matchingOpen(tokens, j) {
            j = open - 1
        } else if j >= 0, tokens[j].text == "(" {
            j -= 1
        }
        guard j >= 0, isName(tokens[j]) else { return .other }
        let name = tokens[j].text
        let isMethod = j > 0 && tokens[j - 1].text == "."
        if isMethod && name == "performAndWait" { return .coreData(perform: false) }
        if isMethod && name == "perform" { return .coreData(perform: true) }
        if let perform = wrappers[name], !isMethod || (j >= 2 && ["self", "Self"].contains(tokens[j - 2].text)) {
            return .coreData(perform: perform)
        }
        return .other
    }

    private static func isFunctionKeyword(_ tokens: [Token], _ i: Int) -> Bool {
        switch tokens[i].text {
        case "func": return i + 1 < tokens.count && isName(tokens[i + 1])
        case "init", "deinit": return !(i > 0 && tokens[i - 1].text == ".")
        default: return false
        }
    }

    /// The attributes and modifiers written before the declaration keyword at `keyword`.
    private static func declarationWords(_ tokens: [Token], before keyword: Int) -> [String] {
        var words: [String] = []
        var j = keyword - 1
        while j >= 0 {
            let text = tokens[j].text
            if modifiers.contains(text) || text.hasPrefix("@") {
                words.append(text)
                j -= 1
            } else if text == ")", let open = matchingOpen(tokens, j), open > 0, tokens[open - 1].text.hasPrefix("@") {
                words.append(tokens[open - 1].text)  // @Test("…"), @Suite(…)
                j = open - 2
            } else {
                break
            }
        }
        return words
    }

    private static func isolation(_ words: [String]) -> Isolation {
        if words.contains("@MainActor") { return .mainActor }
        if words.contains("nonisolated") { return .nonisolated }
        return .inherited
    }

    private static func isMainActor(_ stack: [Scope]) -> Bool {
        for scope in stack.reversed() {
            switch scope {
            case .function(_, let isolation), .type(let isolation):
                if isolation == .mainActor { return true }
                if isolation == .nonisolated { return false }
            case .coreData, .other:
                continue
            }
        }
        return false
    }

    /// Whether the function's own parameter list has a closure parameter handed an
    /// `NSManagedObjectContext`, as in `(_ body: (NSManagedObjectContext) throws -> T)`.
    private static func takesContextClosure(_ tokens: [Token], name: Int, end: Int) -> Bool {
        var i = name + 1
        if i < end, tokens[i].text == "<" {
            var depth = 0
            repeat {
                if tokens[i].text == "<" { depth += 1 }
                if tokens[i].text == ">" && tokens[i - 1].text != "-" { depth -= 1 }
                i += 1
            } while depth > 0 && i < end
        }
        guard i < end, tokens[i].text == "(", let close = matchingClose(tokens, i, limit: end) else { return false }
        for j in (i + 1)..<close where tokens[j].text == "(" {
            guard let group = matchingClose(tokens, j, limit: close) else { continue }
            var k = group + 1
            while k < close, ["async", "throws", "rethrows"].contains(tokens[k].text) { k += 1 }
            if k + 1 < close, tokens[k].text == "-", tokens[k + 1].text == ">",
               tokens[(j + 1)..<group].contains(where: { $0.text == "NSManagedObjectContext" }) {
                return true
            }
        }
        return false
    }

    /// `name(` or `self.name(`/`Type.name(`, but not a method on some other value.
    private static func isUnqualifiedOrOwnCall(_ tokens: [Token], _ t: Int) -> Bool {
        guard t > 0, tokens[t - 1].text == "." else { return true }
        guard t >= 2 else { return false }
        let receiver = tokens[t - 2].text
        return receiver == "self" || receiver == "Self" || receiver.first?.isUppercase == true
    }

    private static func matchingOpen(_ tokens: [Token], _ close: Int) -> Int? {
        var depth = 0
        for j in stride(from: close, through: 0, by: -1) {
            if tokens[j].text == ")" { depth += 1 }
            if tokens[j].text == "(" { depth -= 1; if depth == 0 { return j } }
        }
        return nil
    }

    private static func matchingClose(_ tokens: [Token], _ open: Int, limit: Int) -> Int? {
        var depth = 0
        for j in open..<limit {
            if tokens[j].text == "(" { depth += 1 }
            if tokens[j].text == ")" { depth -= 1; if depth == 0 { return j } }
        }
        return nil
    }

    // MARK: - Tokens

    private static let newline = UInt8(ascii: "\n")
    private static let space = UInt8(ascii: " ")
    private static let slash = UInt8(ascii: "/")
    private static let star = UInt8(ascii: "*")
    private static let quote = UInt8(ascii: "\"")
    private static let hash = UInt8(ascii: "#")
    private static let backslash = UInt8(ascii: "\\")
    private static let openParen = UInt8(ascii: "(")
    private static let closeParen = UInt8(ascii: ")")

    private static func isWordByte(_ byte: UInt8) -> Bool {
        (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z"))
            || (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z"))
            || (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9"))
            || byte == UInt8(ascii: "_") || byte >= 0x80
    }

    private static func isName(_ token: Token) -> Bool {
        guard let first = token.text.utf8.first else { return false }
        return isWordByte(first) && !(first >= UInt8(ascii: "0") && first <= UInt8(ascii: "9"))
    }

    private static func tokens(in code: [UInt8]) -> [Token] {
        var tokens: [Token] = []
        var line = 1
        var i = 0
        while i < code.count {
            let byte = code[i]
            if byte == newline {
                line += 1
                i += 1
            } else if byte == space || byte == UInt8(ascii: "\t") || byte == UInt8(ascii: "\r") {
                i += 1
            } else if isWordByte(byte) || ([hash, UInt8(ascii: "@"), UInt8(ascii: "$")].contains(byte)
                                           && i + 1 < code.count && isWordByte(code[i + 1])) {
                let start = i
                i += 1
                while i < code.count, isWordByte(code[i]) { i += 1 }
                tokens.append(Token(text: String(decoding: code[start..<i], as: UTF8.self), line: line))
            } else {
                tokens.append(Token(text: String(decoding: [byte], as: UTF8.self), line: line))
                i += 1
            }
        }
        return tokens
    }

    /// The source as bytes with comments and string literals' contents blanked to spaces.
    /// Newlines survive, so every byte keeps its line.
    private static func code(of text: String) -> [UInt8] {
        var bytes = Array(text.utf8)
        var i = 0
        skipCode(&bytes, &i, inInterpolation: false)
        return bytes
    }

    private static func blank(_ bytes: inout [UInt8], _ range: Range<Int>) {
        for k in range where bytes[k] != newline { bytes[k] = space }
    }

    /// Advances through code, blanking comments and literals, to the end of the source or,
    /// inside a string interpolation, to the `)` that closes it.
    private static func skipCode(_ bytes: inout [UInt8], _ i: inout Int, inInterpolation: Bool) {
        var depth = 0
        while i < bytes.count {
            let byte = bytes[i]
            let next = i + 1 < bytes.count ? bytes[i + 1] : 0
            if byte == slash && next == slash {
                let start = i
                while i < bytes.count, bytes[i] != newline { i += 1 }
                blank(&bytes, start..<i)
            } else if byte == slash && next == star {
                let start = i
                var nesting = 0
                while i < bytes.count {
                    if bytes[i] == slash, i + 1 < bytes.count, bytes[i + 1] == star {
                        nesting += 1
                        i += 2
                    } else if bytes[i] == star, i + 1 < bytes.count, bytes[i + 1] == slash {
                        nesting -= 1
                        i += 2
                        if nesting == 0 { break }
                    } else {
                        i += 1
                    }
                }
                blank(&bytes, start..<i)
            } else if byte == quote || (byte == hash && bytes[(i + run(of: hash, in: bytes, at: i))...].first == quote) {
                skipString(&bytes, &i)
            } else if inInterpolation && byte == openParen {
                depth += 1
                i += 1
            } else if inInterpolation && byte == closeParen {
                if depth == 0 { return }
                depth -= 1
                i += 1
            } else {
                i += 1
            }
        }
    }

    /// From a string literal's opening delimiter (`"`, `"""`, `#"`…) to past its closing one,
    /// blanking everything between, interpolations included.
    private static func skipString(_ bytes: inout [UInt8], _ i: inout Int) {
        let hashes = run(of: hash, in: bytes, at: i)
        i += hashes
        let quotes = run(of: quote, in: bytes, at: i) >= 3 ? 3 : 1
        i += quotes
        let start = i
        while i < bytes.count {
            if bytes[i] == backslash && run(of: hash, in: bytes, at: i + 1) >= hashes {
                let next = i + 1 + hashes
                if next < bytes.count && bytes[next] == openParen {
                    i = next + 1
                    skipCode(&bytes, &i, inInterpolation: true)
                    i = min(i + 1, bytes.count)  // past the interpolation's `)`
                } else {
                    i = min(next + 1, bytes.count)  // past the escaped character
                }
                continue
            }
            if quotes == 1 && bytes[i] == newline { break }
            if run(of: quote, in: bytes, at: i) >= quotes && run(of: hash, in: bytes, at: i + quotes) >= hashes {
                blank(&bytes, start..<i)
                i += quotes + hashes
                return
            }
            i += 1
        }
        blank(&bytes, start..<i)
    }

    private static func run(of byte: UInt8, in bytes: [UInt8], at index: Int) -> Int {
        var count = 0
        while index + count < bytes.count, bytes[index + count] == byte { count += 1 }
        return count
    }
}
