import Foundation
import Testing

@testable import Terminatab

@Suite struct SessionManagerTests {
    @Test func createSessionReturnsUniqueId() async throws {
        let manager = SessionManager()
        let id1 = try await manager.createSession(cols: 80, rows: 24)
        let id2 = try await manager.createSession(cols: 80, rows: 24)

        #expect(id1 != id2)
        #expect(id1.count == 16)
        #expect(id2.count == 16)

        await manager.removeSession(id1)
        await manager.removeSession(id2)
    }

    @Test func getSessionReturnsCreatedSession() async throws {
        let manager = SessionManager()
        let id = try await manager.createSession(cols: 80, rows: 24)
        let session = await manager.getSession(id)
        #expect(session != nil)
        #expect(session?.id == id)

        await manager.removeSession(id)
    }

    @Test func getNonexistentSessionReturnsNil() async {
        let manager = SessionManager()
        let session = await manager.getSession("nonexistent12345")
        #expect(session == nil)
    }

    @Test func removeSessionDeletesIt() async throws {
        let manager = SessionManager()
        let id = try await manager.createSession(cols: 80, rows: 24)
        await manager.removeSession(id)
        let session = await manager.getSession(id)
        #expect(session == nil)
    }

    @Test func cleanupRemovesExpiredDisconnectedSessions() async throws {
        let manager = SessionManager()
        let id = try await manager.createSession(cols: 80, rows: 24)
        await manager.markDisconnected(id)

        // Use timeout=0 so the session is immediately expired
        await manager.cleanup(timeout: 0)
        let session = await manager.getSession(id)
        #expect(session == nil)
    }

    @Test func cleanupPreservesConnectedSessions() async throws {
        let manager = SessionManager()
        let id = try await manager.createSession(cols: 80, rows: 24)

        // Even with timeout=0, connected sessions should be preserved
        await manager.cleanup(timeout: 0)
        let session = await manager.getSession(id)
        #expect(session != nil)

        await manager.removeSession(id)
    }

    @Test func cleanupPreservesRecentlyDisconnectedSessions() async throws {
        let manager = SessionManager()
        let id = try await manager.createSession(cols: 80, rows: 24)
        await manager.markDisconnected(id)

        // With a large timeout, recently disconnected sessions should be preserved
        await manager.cleanup(timeout: 3600)
        let session = await manager.getSession(id)
        #expect(session != nil)

        await manager.removeSession(id)
    }
}
