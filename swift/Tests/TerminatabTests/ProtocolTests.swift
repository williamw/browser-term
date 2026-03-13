import Foundation
import Testing

@testable import Terminatab

@Suite struct ProtocolTests {
    @Test func parseNewSessionMessage() throws {
        let msg = try parseClientMessage("{\"type\":\"new_session\"}")
        guard case .newSession = msg else {
            Issue.record("Expected newSession, got \(msg)")
            return
        }
    }

    @Test func parseAttachMessage() throws {
        let msg = try parseClientMessage("{\"type\":\"attach\",\"session_id\":\"abc123\"}")
        guard case .attach(let sessionId) = msg else {
            Issue.record("Expected attach")
            return
        }
        #expect(sessionId == "abc123")
    }

    @Test func parseInputMessage() throws {
        let msg = try parseClientMessage("{\"type\":\"input\",\"session_id\":\"abc123\",\"data\":\"ls\\r\"}")
        guard case .input(let sessionId, let data) = msg else {
            Issue.record("Expected input")
            return
        }
        #expect(sessionId == "abc123")
        #expect(data == "ls\r")
    }

    @Test func parseResizeMessage() throws {
        let msg = try parseClientMessage("{\"type\":\"resize\",\"session_id\":\"abc123\",\"cols\":120,\"rows\":40}")
        guard case .resize(let sessionId, let cols, let rows) = msg else {
            Issue.record("Expected resize")
            return
        }
        #expect(sessionId == "abc123")
        #expect(cols == 120)
        #expect(rows == 40)
    }

    @Test func parseInvalidMessageType() {
        #expect(throws: ProtocolError.unknownMessageType) {
            try parseClientMessage("{\"type\":\"unknown\"}")
        }
    }

    @Test func parseMalformedJSON() {
        #expect(throws: ProtocolError.invalidJSON) {
            try parseClientMessage("not json at all")
        }
    }

    @Test func serializeSessionCreated() throws {
        let json = serializeServerMessage(.sessionCreated(sessionId: "abc123"))
        let data = json.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(obj["type"] as? String == "session_created")
        #expect(obj["session_id"] as? String == "abc123")
    }

    @Test func serializeOutput() throws {
        let json = serializeServerMessage(.output(sessionId: "abc123", data: Data("hello\n".utf8)))
        let data = json.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(obj["type"] as? String == "output")
        #expect(obj["session_id"] as? String == "abc123")
        #expect(obj["data"] as? String == "hello\n")
    }

    @Test func serializeOutputWithEscapeSequences() throws {
        // Terminal escape sequence: ESC [ 3 1 m (red text)
        let bytes: [UInt8] = [0x1B, 0x5B, 0x33, 0x31, 0x6D, 0x68, 0x69] // \e[31mhi
        let json = serializeServerMessage(.output(sessionId: "abc123", data: Data(bytes)))
        let data = json.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let outputData = obj["data"] as? String
        #expect(outputData == "\u{1B}[31mhi")
    }

    @Test func serializeSessionEnded() throws {
        let json = serializeServerMessage(.sessionEnded(sessionId: "abc123"))
        let data = json.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(obj["type"] as? String == "session_ended")
        #expect(obj["session_id"] as? String == "abc123")
    }

    @Test func serializeError() throws {
        let json = serializeServerMessage(.error(message: "not found"))
        let data = json.data(using: .utf8)!
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(obj["type"] as? String == "error")
        #expect(obj["message"] as? String == "not found")
    }
}
