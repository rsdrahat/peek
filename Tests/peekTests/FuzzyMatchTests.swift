import XCTest
@testable import peek

final class FuzzyMatchTests: XCTestCase {
    func testEmptyQueryReturnsZero() {
        XCTAssertEqual(FuzzyMatch.score(query: "", in: "anything.md"), 0)
    }

    func testNonSubsequenceReturnsNil() {
        XCTAssertNil(FuzzyMatch.score(query: "xyz", in: "README.md"))
    }

    func testCaseInsensitive() {
        XCTAssertNotNil(FuzzyMatch.score(query: "readme", in: "README.md"))
        XCTAssertNotNil(FuzzyMatch.score(query: "README", in: "readme.md"))
    }

    func testPrefixBeatsMiddle() throws {
        let a = try XCTUnwrap(FuzzyMatch.score(query: "rd", in: "readme.md"))
        let b = try XCTUnwrap(FuzzyMatch.score(query: "rd", in: "thread.md"))
        XCTAssertGreaterThan(a, b)
    }

    func testContiguousBeatsScattered() throws {
        let contiguous = try XCTUnwrap(FuzzyMatch.score(query: "auth", in: "auth.md"))
        let scattered = try XCTUnwrap(FuzzyMatch.score(query: "auth", in: "a_u_t_h.md"))
        XCTAssertGreaterThan(contiguous, scattered)
    }

    func testWordStartBeatsMidWord() throws {
        // "log" hits the start of a path component in "src/login.md"
        let wordStart = try XCTUnwrap(FuzzyMatch.score(query: "log", in: "src/login.md"))
        // "log" is mid-word in "blogs.md"
        let midWord = try XCTUnwrap(FuzzyMatch.score(query: "log", in: "blogs.md"))
        XCTAssertGreaterThan(wordStart, midWord)
    }

    func testShorterTiesWin() throws {
        let short = try XCTUnwrap(FuzzyMatch.score(query: "a", in: "a.md"))
        let long = try XCTUnwrap(FuzzyMatch.score(query: "a", in: "a-much-longer-name.md"))
        XCTAssertGreaterThan(short, long)
    }

    func testPathSeparatorBoostsComponentStart() throws {
        // "n" at the start of "notes/" beats "n" mid-word in something like "snake.md"
        let component = try XCTUnwrap(FuzzyMatch.score(query: "n", in: "notes/x.md"))
        let mid = try XCTUnwrap(FuzzyMatch.score(query: "n", in: "snake.md"))
        XCTAssertGreaterThan(component, mid)
    }

    func testSubsequenceMatchesAcrossSegments() throws {
        // Classic agent flow: query the file by its key terms ignoring delimiters.
        XCTAssertNotNil(FuzzyMatch.score(query: "athlogin", in: "auth/login.md"))
        XCTAssertNotNil(FuzzyMatch.score(query: "amd", in: "a/b/c.md"))
    }

    func testExactSubstringBeatsScatteredSubsequence() throws {
        // Both "auth.md" and "a-uniform-test-here.md" are subsequence-matches
        // for "auth", but the contiguous one is what the user actually meant.
        let candidates = ["a-uniform-test-here.md", "auth.md"]
        let scored: [(Double, String)] = candidates.compactMap { name in
            guard let s = FuzzyMatch.score(query: "auth", in: name) else { return nil }
            return (s, name)
        }
        let ranked = scored.sorted { $0.0 > $1.0 }.map { $0.1 }
        XCTAssertEqual(ranked.first, "auth.md")
    }
}
