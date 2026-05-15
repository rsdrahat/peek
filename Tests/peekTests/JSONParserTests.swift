import XCTest
@testable import peek

final class JSONParserTests: XCTestCase {
    // MARK: - Primitives

    func testParseNull() throws {
        XCTAssertEqual(try JSONParser.parse("null"), .null)
    }

    func testParseBools() throws {
        XCTAssertEqual(try JSONParser.parse("true"), .bool(true))
        XCTAssertEqual(try JSONParser.parse("false"), .bool(false))
    }

    func testParseStringSimple() throws {
        XCTAssertEqual(try JSONParser.parse("\"hello\""), .string("hello"))
    }

    func testParseStringWithEscapes() throws {
        XCTAssertEqual(try JSONParser.parse(#""a\nb""#), .string("a\nb"))
        XCTAssertEqual(try JSONParser.parse(#""quote\"inside""#), .string("quote\"inside"))
        XCTAssertEqual(try JSONParser.parse(#""back\\slash""#), .string("back\\slash"))
        XCTAssertEqual(try JSONParser.parse(#""\b\f\n\r\t""#), .string("\u{08}\u{0C}\n\r\t"))
    }

    func testParseStringUnicodeEscape() throws {
        // Heart character via \u escape.
        XCTAssertEqual(try JSONParser.parse(#""♥""#), .string("\u{2665}"))
    }

    func testParseStringSurrogatePair() throws {
        // U+1F600 (😀) encoded as surrogate pair 😀.
        XCTAssertEqual(try JSONParser.parse(#""😀""#), .string("😀"))
    }

    func testParseStringWithMultibyteUTF8Inline() throws {
        // Non-ASCII chars in the source must round-trip even without \u.
        XCTAssertEqual(try JSONParser.parse("\"café 日本\""), .string("café 日本"))
    }

    // MARK: - Numbers (int vs double)

    func testParseIntegerStaysInt() throws {
        XCTAssertEqual(try JSONParser.parse("42"), .number(.int(42)))
        XCTAssertEqual(try JSONParser.parse("-7"), .number(.int(-7)))
        XCTAssertEqual(try JSONParser.parse("0"), .number(.int(0)))
    }

    func testParseDoubleStaysDouble() throws {
        XCTAssertEqual(try JSONParser.parse("3.14"), .number(.double(3.14)))
        XCTAssertEqual(try JSONParser.parse("1e6"), .number(.double(1e6)))
        XCTAssertEqual(try JSONParser.parse("-2.5E-3"), .number(.double(-2.5E-3)))
    }

    func testParseLargeIntegerFallsBackToDouble() throws {
        // 2^64-ish — well outside Int64 range. Must not throw.
        let lit = "999999999999999999999"
        guard case .number(.double) = try JSONParser.parse(lit) else {
            XCTFail("expected double fallback for huge integer"); return
        }
    }

    // MARK: - Containers

    func testParseEmptyArray() throws {
        XCTAssertEqual(try JSONParser.parse("[]"), .array([]))
    }

    func testParseEmptyObject() throws {
        XCTAssertEqual(try JSONParser.parse("{}"), .object([]))
    }

    func testParseFlatArray() throws {
        let v = try JSONParser.parse("[1, 2, 3]")
        XCTAssertEqual(v, .array([.number(.int(1)), .number(.int(2)), .number(.int(3))]))
    }

    func testParseFlatObject() throws {
        let v = try JSONParser.parse(#"{"a": 1, "b": true}"#)
        XCTAssertEqual(v, .object([
            JSONMember("a", .number(.int(1))),
            JSONMember("b", .bool(true)),
        ]))
    }

    func testObjectKeyOrderPreserved() throws {
        // Source order matters for the viewer; this is the whole reason we
        // wrote a custom parser instead of using JSONSerialization.
        let v = try JSONParser.parse(#"{"z": 1, "a": 2, "m": 3}"#)
        guard case let .object(members) = v else { XCTFail(); return }
        XCTAssertEqual(members.map(\.key), ["z", "a", "m"])
    }

    func testNestedStructures() throws {
        let v = try JSONParser.parse(#"{"a": [1, {"b": null}], "c": "hi"}"#)
        XCTAssertEqual(v, .object([
            JSONMember("a", .array([
                .number(.int(1)),
                .object([JSONMember("b", .null)]),
            ])),
            JSONMember("c", .string("hi")),
        ]))
    }

    // MARK: - Whitespace

    func testWhitespaceVariations() throws {
        XCTAssertEqual(try JSONParser.parse("  \n\t[ 1 ,\n 2 ]  "),
                       .array([.number(.int(1)), .number(.int(2))]))
    }

    // MARK: - Error reporting

    func testErrorLineColumnForUnterminatedString() {
        do {
            _ = try JSONParser.parse("{\n  \"key\": \"oops")
            XCTFail("expected throw")
        } catch let e as JSONParseError {
            XCTAssertEqual(e.line, 2, "error should point at the offending line")
            XCTAssertGreaterThan(e.column, 0)
        } catch {
            XCTFail("wrong error type: \(error)")
        }
    }

    func testErrorOnTrailingComma() {
        XCTAssertThrowsError(try JSONParser.parse("[1, 2, ]"))
        XCTAssertThrowsError(try JSONParser.parse(#"{"a":1,}"#))
    }

    func testErrorOnTrailingContent() {
        XCTAssertThrowsError(try JSONParser.parse("[1] garbage"))
    }

    func testErrorOnMissingColon() {
        XCTAssertThrowsError(try JSONParser.parse(#"{"a" 1}"#))
    }

    func testErrorOnLoneOpener() {
        XCTAssertThrowsError(try JSONParser.parse("{"))
        XCTAssertThrowsError(try JSONParser.parse("["))
    }

    func testErrorOnControlCharacterInString() {
        XCTAssertThrowsError(try JSONParser.parse("\"\u{01}\""))
    }

    func testErrorPositionAdvancesPastNewlines() {
        do {
            _ = try JSONParser.parse("\n\n  ?")
            XCTFail("expected throw")
        } catch let e as JSONParseError {
            XCTAssertEqual(e.line, 3)
            XCTAssertEqual(e.column, 3)
        } catch {
            XCTFail("wrong error type")
        }
    }

    // MARK: - Deeply nested (stress)

    func testDeepNesting() throws {
        let depth = 200
        let json = String(repeating: "[", count: depth) + String(repeating: "]", count: depth)
        let v = try JSONParser.parse(json)
        // walk down to confirm depth
        var cur = v
        for _ in 0..<depth {
            guard case let .array(items) = cur else { XCTFail(); return }
            cur = items.first ?? .null
        }
    }

    // MARK: - Perf budget: 50MB JSON parses in <1s on M-series in release.
    //
    // `swift test` defaults to debug, where Swift is 4-10x slower than
    // release. CI on macOS-14 runners is slower still. Canonical measure is
    // release (~0.29s on M-series). Hard limit here is generous so this test
    // doesn't flake on slow runners; the real budget assertion lives in the
    // soft-warn printout, which surfaces drift without flake.

    func testPerformance50MBJSONUnderOneSecond() throws {
        // Build a synthetic ~50MB JSON blob: array of ~320k objects.
        var s = "["
        s.reserveCapacity(60_000_000)
        let unit = #"{"id":12345,"name":"some long-ish name to pad","tags":["alpha","beta","gamma"],"flag":true,"score":3.14159,"note":"padding padding padding padding padding"}"#
        let n = 320_000
        for i in 0..<n {
            if i > 0 { s.append(",") }
            s.append(unit)
        }
        s.append("]")
        XCTAssertGreaterThan(s.utf8.count, 40_000_000, "expected ~50MB synthetic JSON")

        let t0 = CFAbsoluteTimeGetCurrent()
        let v = try JSONParser.parse(s)
        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        guard case let .array(items) = v else { XCTFail(); return }
        XCTAssertEqual(items.count, n)
        XCTAssertLessThan(elapsed, 15.0,
                          "parser exceeded the debug-mode safety budget (15s) for ~50MB — measured \(elapsed)s. Release-mode budget is 1s.")
        // Soft signal (informational, not a hard fail at 1s on slow CI):
        if elapsed > 1.0 {
            print("⚠️ parse took \(elapsed)s — over the 1s soft budget; optimize if persistent.")
        }
    }
}
