import Foundation

// MARK: - Client → Server Messages

enum ClientMessage {
    case newSession
    case attach(sessionId: String)
    case input(sessionId: String, data: String)
    case resize(sessionId: String, cols: UInt16, rows: UInt16)
}

// MARK: - Server → Client Messages

enum ServerMessage: Sendable {
    case sessionCreated(sessionId: String)
    case output(sessionId: String, data: Data)
    case sessionEnded(sessionId: String)
    case error(message: String)
}

// MARK: - Parsing

enum ProtocolError: Error {
    case unknownMessageType
    case missingField
    case invalidJSON
}

private struct RawMessage: Decodable {
    let type: String
    let session_id: String?
    let data: String?
    let cols: UInt16?
    let rows: UInt16?
    let message: String?
}

func parseClientMessage(_ json: String) throws -> ClientMessage {
    guard let data = json.data(using: .utf8) else {
        throw ProtocolError.invalidJSON
    }

    let raw: RawMessage
    do {
        raw = try JSONDecoder().decode(RawMessage.self, from: data)
    } catch {
        throw ProtocolError.invalidJSON
    }

    switch raw.type {
    case "new_session":
        return .newSession
    case "attach":
        guard let sessionId = raw.session_id else { throw ProtocolError.missingField }
        return .attach(sessionId: sessionId)
    case "input":
        guard let sessionId = raw.session_id, let inputData = raw.data else {
            throw ProtocolError.missingField
        }
        return .input(sessionId: sessionId, data: inputData)
    case "resize":
        guard let sessionId = raw.session_id, let cols = raw.cols, let rows = raw.rows else {
            throw ProtocolError.missingField
        }
        return .resize(sessionId: sessionId, cols: cols, rows: rows)
    default:
        throw ProtocolError.unknownMessageType
    }
}

// MARK: - Serialization

func serializeServerMessage(_ msg: ServerMessage) -> String {
    switch msg {
    case .sessionCreated(let sessionId):
        return "{\"type\":\"session_created\",\"session_id\":\(jsonString(sessionId))}"
    case .output(let sessionId, let data):
        return String(decoding: serializeOutputData(sessionId: sessionId, data: data), as: UTF8.self)
    case .sessionEnded(let sessionId):
        return "{\"type\":\"session_ended\",\"session_id\":\(jsonString(sessionId))}"
    case .error(let message):
        return "{\"type\":\"error\",\"message\":\(jsonString(message))}"
    }
}

/// JSON-encode a Swift String value with proper escaping.
private func jsonString(_ s: String) -> String {
    var result = "\""
    for char in s {
        switch char {
        case "\"": result += "\\\""
        case "\\": result += "\\\\"
        case "\n": result += "\\n"
        case "\r": result += "\\r"
        case "\t": result += "\\t"
        default:
            if char.asciiValue != nil && char.asciiValue! < 0x20 {
                result += String(format: "\\u%04x", char.asciiValue!)
            } else {
                result.append(char)
            }
        }
    }
    result += "\""
    return result
}

/// JSON-escape raw bytes into a [UInt8] buffer (a quoted JSON string value).
/// Returns raw bytes to avoid String(decoding:as:UTF8.self) which replaces
/// incomplete UTF-8 sequences (from chunk boundaries) with U+FFFD.
private func jsonEscapeBytes(_ data: Data) -> [UInt8] {
    var buf: [UInt8] = [0x22] // opening "
    for byte in data {
        switch byte {
        case 0x22: buf.append(contentsOf: [0x5C, 0x22])       // \"
        case 0x5C: buf.append(contentsOf: [0x5C, 0x5C])       // \\
        case 0x0A: buf.append(contentsOf: [0x5C, 0x6E])       // \n
        case 0x0D: buf.append(contentsOf: [0x5C, 0x72])       // \r
        case 0x09: buf.append(contentsOf: [0x5C, 0x74])       // \t
        case 0x00...0x08, 0x0B, 0x0C, 0x0E...0x1F:
            let hex = String(format: "\\u%04x", byte)
            buf.append(contentsOf: hex.utf8)
        default:
            buf.append(byte) // raw byte — preserves multi-byte UTF-8 intact
        }
    }
    buf.append(0x22) // closing "
    return buf
}

/// Build a complete JSON output message as raw Data, bypassing Swift String
/// to avoid UTF-8 validation that corrupts incomplete sequences at chunk boundaries.
func serializeOutputData(sessionId: String, data: Data) -> Data {
    var buf: [UInt8] = []
    buf.append(contentsOf: #"{"type":"output","session_id":"#.utf8)
    buf.append(contentsOf: jsonString(sessionId).utf8)
    buf.append(contentsOf: #","data":"#.utf8)
    buf.append(contentsOf: jsonEscapeBytes(data))
    buf.append(contentsOf: "}".utf8)
    return Data(buf)
}

/// Returns the number of trailing bytes that form an incomplete UTF-8 sequence.
func incompleteUTF8Tail(_ data: Data) -> Int {
    guard !data.isEmpty else { return 0 }
    for i in 1...min(3, data.count) {
        let byte = data[data.endIndex - i]
        if byte & 0x80 == 0 {
            return 0 // ASCII — sequence is complete
        } else if byte & 0xC0 != 0x80 {
            // Start byte — check if sequence is complete
            let expected: Int
            if byte & 0xE0 == 0xC0 { expected = 2 }
            else if byte & 0xF0 == 0xE0 { expected = 3 }
            else if byte & 0xF8 == 0xF0 { expected = 4 }
            else { return 0 } // Invalid start byte
            return i < expected ? i : 0
        }
        // Continuation byte (10xxxxxx) — keep scanning backward
    }
    return min(3, data.count) // All continuation bytes, no start byte
}
