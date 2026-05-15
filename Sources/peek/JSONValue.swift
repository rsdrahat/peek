import Foundation

/// A parsed JSON value preserving original object key order, int-vs-double
/// number distinction, and source position for error messages.
///
/// We deliberately do NOT use Foundation's `JSONSerialization` here: it
/// returns `NSDictionary` (unordered) and `NSNumber` (loses int-vs-double
/// distinction). Both matter for a viewer where users expect keys to render
/// in source order and integers not to grow a `.0` suffix.
public indirect enum JSONValue: Equatable, Sendable {
    case object([JSONMember])
    case array([JSONValue])
    case string(String)
    case number(JSONNumber)
    case bool(Bool)
    case null
}

public struct JSONMember: Equatable, Sendable {
    public let key: String
    public let value: JSONValue
    public init(_ key: String, _ value: JSONValue) {
        self.key = key
        self.value = value
    }
}

public enum JSONNumber: Equatable, Sendable {
    case int(Int64)
    case double(Double)

    public var asDouble: Double {
        switch self {
        case .int(let i): return Double(i)
        case .double(let d): return d
        }
    }
}

public struct JSONParseError: Error, Equatable, Sendable {
    public let line: Int
    public let column: Int
    public let message: String

    public var localizedDescription: String {
        "line \(line), column \(column): \(message)"
    }
}

/// Recursive-descent JSON parser. Operates on UTF-8 bytes; only the string
/// payloads are decoded into Swift `String`. ~3x lower memory than walking
/// `[Unicode.Scalar]` for large files, and structural bytes are pure ASCII
/// so byte comparisons are correct.
public struct JSONParser {
    private let bytes: [UInt8]
    private var index: Int = 0
    private var line: Int = 1
    private var column: Int = 1

    public static func parse(_ text: String) throws -> JSONValue {
        var p = JSONParser(bytes: Array(text.utf8))
        return try p.parseTopLevel()
    }

    public static func parse(data: Data) throws -> JSONValue {
        var p = JSONParser(bytes: Array(data))
        return try p.parseTopLevel()
    }

    private init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    private mutating func parseTopLevel() throws -> JSONValue {
        skipWhitespace()
        let v = try parseValue()
        skipWhitespace()
        if index < bytes.count {
            throw error("unexpected trailing content")
        }
        return v
    }

    // MARK: - Scanner

    private mutating func advance() {
        if index < bytes.count {
            let b = bytes[index]
            if b == 0x0A { // \n
                line += 1
                column = 1
            } else {
                column += 1
            }
            index += 1
        }
    }

    private mutating func skipWhitespace() {
        while index < bytes.count {
            switch bytes[index] {
            case 0x20, 0x09, 0x0A, 0x0D: // space, tab, \n, \r
                advance()
            default:
                return
            }
        }
    }

    private func peek() -> UInt8? {
        index < bytes.count ? bytes[index] : nil
    }

    private func error(_ msg: String) -> JSONParseError {
        JSONParseError(line: line, column: column, message: msg)
    }

    // MARK: - Values

    private mutating func parseValue() throws -> JSONValue {
        skipWhitespace()
        guard let c = peek() else { throw error("unexpected end of input") }
        switch c {
        case 0x7B: return try parseObject()       // {
        case 0x5B: return try parseArray()        // [
        case 0x22: return .string(try parseString()) // "
        case 0x74, 0x66: return .bool(try parseBool())  // t / f
        case 0x6E: try parseNull(); return .null  // n
        case 0x2D, 0x30...0x39: return .number(try parseNumber()) // -, 0-9
        default:
            throw error("unexpected character '\(asciiOrEsc(c))'")
        }
    }

    private mutating func parseObject() throws -> JSONValue {
        advance() // consume {
        var members: [JSONMember] = []
        skipWhitespace()
        if peek() == 0x7D { advance(); return .object(members) }

        while true {
            skipWhitespace()
            guard peek() == 0x22 else {
                throw error("expected string key (object member)")
            }
            let key = try parseString()
            skipWhitespace()
            guard peek() == 0x3A else { throw error("expected ':' after key") }
            advance() // :
            let value = try parseValue()
            members.append(JSONMember(key, value))
            skipWhitespace()
            switch peek() {
            case 0x2C: advance(); continue       // ,
            case 0x7D: advance(); return .object(members) // }
            default: throw error("expected ',' or '}' in object")
            }
        }
    }

    private mutating func parseArray() throws -> JSONValue {
        advance() // [
        var items: [JSONValue] = []
        skipWhitespace()
        if peek() == 0x5D { advance(); return .array(items) }

        while true {
            items.append(try parseValue())
            skipWhitespace()
            switch peek() {
            case 0x2C: advance(); continue
            case 0x5D: advance(); return .array(items)
            default: throw error("expected ',' or ']' in array")
            }
        }
    }

    private mutating func parseString() throws -> String {
        guard peek() == 0x22 else { throw error("expected '\"'") }
        advance()
        // Fast path: scan ahead for a plain-ASCII run with no escapes; if we
        // hit the closing quote first, we can build the result in one shot.
        let runStart = index
        while index < bytes.count {
            let b = bytes[index]
            if b == 0x22 { // "
                let result = String(decoding: bytes[runStart..<index], as: UTF8.self)
                advance()
                return result
            }
            if b == 0x5C { break } // backslash → fall through to slow path
            if b < 0x20 {
                throw error("control character in string literal")
            }
            advance()
        }

        // Slow path: at least one escape sequence. Rebuild via byte buffer.
        var out: [UInt8] = Array(bytes[runStart..<index])
        while index < bytes.count {
            let b = bytes[index]
            if b == 0x22 {
                advance()
                return String(decoding: out, as: UTF8.self)
            }
            if b == 0x5C {
                advance()
                guard let esc = peek() else { throw error("unterminated escape") }
                switch esc {
                case 0x22: out.append(0x22); advance()
                case 0x5C: out.append(0x5C); advance()
                case 0x2F: out.append(0x2F); advance()
                case 0x62: out.append(0x08); advance() // \b
                case 0x66: out.append(0x0C); advance() // \f
                case 0x6E: out.append(0x0A); advance() // \n
                case 0x72: out.append(0x0D); advance() // \r
                case 0x74: out.append(0x09); advance() // \t
                case 0x75:
                    advance()
                    let scalar = try parseUnicodeEscape()
                    appendUTF8(scalar, to: &out)
                default:
                    throw error("invalid escape sequence")
                }
            } else if b < 0x20 {
                throw error("control character in string literal")
            } else {
                out.append(b)
                advance()
            }
        }
        throw error("unterminated string")
    }

    private mutating func parseUnicodeEscape() throws -> Unicode.Scalar {
        let first = try parseHex4()
        // Handle UTF-16 surrogate pair.
        if (0xD800...0xDBFF).contains(first) {
            guard peek() == 0x5C else { throw error("expected low surrogate") }
            advance()
            guard peek() == 0x75 else { throw error("expected \\u") }
            advance()
            let second = try parseHex4()
            guard (0xDC00...0xDFFF).contains(second) else {
                throw error("invalid low surrogate")
            }
            let code = 0x10000 + (Int(first - 0xD800) << 10) + Int(second - 0xDC00)
            guard let scalar = Unicode.Scalar(code) else { throw error("invalid unicode scalar") }
            return scalar
        }
        guard let scalar = Unicode.Scalar(Int(first)) else { throw error("invalid unicode scalar") }
        return scalar
    }

    private mutating func parseHex4() throws -> UInt32 {
        var value: UInt32 = 0
        for _ in 0..<4 {
            guard let b = peek(), let nibble = hexNibble(b) else {
                throw error("invalid \\u escape (expected 4 hex digits)")
            }
            value = (value << 4) | UInt32(nibble)
            advance()
        }
        return value
    }

    private func hexNibble(_ b: UInt8) -> UInt8? {
        switch b {
        case 0x30...0x39: return b - 0x30           // 0-9
        case 0x61...0x66: return b - 0x61 + 10      // a-f
        case 0x41...0x46: return b - 0x41 + 10      // A-F
        default: return nil
        }
    }

    private func appendUTF8(_ scalar: Unicode.Scalar, to out: inout [UInt8]) {
        let v = scalar.value
        if v < 0x80 {
            out.append(UInt8(v))
        } else if v < 0x800 {
            out.append(UInt8(0xC0 | (v >> 6)))
            out.append(UInt8(0x80 | (v & 0x3F)))
        } else if v < 0x10000 {
            out.append(UInt8(0xE0 | (v >> 12)))
            out.append(UInt8(0x80 | ((v >> 6) & 0x3F)))
            out.append(UInt8(0x80 | (v & 0x3F)))
        } else {
            out.append(UInt8(0xF0 | (v >> 18)))
            out.append(UInt8(0x80 | ((v >> 12) & 0x3F)))
            out.append(UInt8(0x80 | ((v >> 6) & 0x3F)))
            out.append(UInt8(0x80 | (v & 0x3F)))
        }
    }

    private mutating func parseBool() throws -> Bool {
        if matches("true") { return true }
        if matches("false") { return false }
        throw error("invalid literal")
    }

    private mutating func parseNull() throws {
        if matches("null") { return }
        throw error("invalid literal")
    }

    private mutating func matches(_ keyword: String) -> Bool {
        let kBytes = Array(keyword.utf8)
        guard index + kBytes.count <= bytes.count else { return false }
        for i in 0..<kBytes.count {
            if bytes[index + i] != kBytes[i] { return false }
        }
        for _ in 0..<kBytes.count { advance() }
        return true
    }

    private mutating func parseNumber() throws -> JSONNumber {
        let start = index
        var isDouble = false
        if peek() == 0x2D { advance() }
        // integer part
        if peek() == 0x30 {
            advance()
        } else if let b = peek(), (0x31...0x39).contains(b) {
            while let b = peek(), (0x30...0x39).contains(b) { advance() }
        } else {
            throw error("invalid number")
        }
        // fraction
        if peek() == 0x2E {
            isDouble = true
            advance()
            guard let b = peek(), (0x30...0x39).contains(b) else {
                throw error("expected digit after '.'")
            }
            while let b = peek(), (0x30...0x39).contains(b) { advance() }
        }
        // exponent
        if let b = peek(), b == 0x65 || b == 0x45 {
            isDouble = true
            advance()
            if let s = peek(), s == 0x2B || s == 0x2D { advance() }
            guard let b = peek(), (0x30...0x39).contains(b) else {
                throw error("expected digit in exponent")
            }
            while let b = peek(), (0x30...0x39).contains(b) { advance() }
        }
        let lit = String(decoding: bytes[start..<index], as: UTF8.self)
        if isDouble {
            guard let d = Double(lit) else { throw error("number out of range") }
            return .double(d)
        }
        if let i = Int64(lit) { return .int(i) }
        // Integer that overflows Int64 — degrade to double rather than fail.
        guard let d = Double(lit) else { throw error("number out of range") }
        return .double(d)
    }

    private func asciiOrEsc(_ b: UInt8) -> String {
        if (0x20...0x7E).contains(b) {
            return String(UnicodeScalar(b))
        }
        return String(format: "\\x%02X", b)
    }
}
