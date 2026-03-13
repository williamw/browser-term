import Darwin
import Foundation
import Testing

@testable import Terminatab

@Suite struct PTYTests {
    @Test func spawnCreatesValidPTY() throws {
        let pty = try PTY.spawn(cols: 80, rows: 24)
        #expect(pty.masterFD > 0)
        #expect(pty.childPID > 0)
        pty.close()
    }

    @Test func ptyReadReturnsShellOutput() throws {
        let pty = try PTY.spawn(cols: 80, rows: 24)
        defer { pty.close() }

        Thread.sleep(forTimeInterval: 0.5)

        var buf = [UInt8](repeating: 0, count: 4096)
        let n = buf.withUnsafeMutableBytes { pty.read(into: $0) }
        #expect(n > 0)
    }

    @Test func ptyWriteSendsInput() throws {
        let pty = try PTY.spawn(cols: 80, rows: 24)
        defer { pty.close() }

        Thread.sleep(forTimeInterval: 0.5)

        // Drain initial output
        var buf = [UInt8](repeating: 0, count: 4096)
        _ = buf.withUnsafeMutableBytes { pty.read(into: $0) }

        pty.write("echo hello_test_marker\n")
        Thread.sleep(forTimeInterval: 0.5)

        let n = buf.withUnsafeMutableBytes { pty.read(into: $0) }
        let output = String(bytes: buf[..<n], encoding: .utf8) ?? ""
        #expect(output.contains("hello_test_marker"))
    }

    @Test func ptyResizeUpdatesDimensions() throws {
        let pty = try PTY.spawn(cols: 80, rows: 24)
        defer { pty.close() }

        try pty.resize(cols: 120, rows: 40)

        var ws = winsize()
        let ret = ioctl(pty.masterFD, TIOCGWINSZ, &ws)
        #expect(ret == 0)
        #expect(ws.ws_col == 120)
        #expect(ws.ws_row == 40)
    }

    @Test func ptyCloseKillsChildProcess() throws {
        let pty = try PTY.spawn(cols: 80, rows: 24)
        let childPID = pty.childPID

        pty.close()
        // waitpid with WNOHANG may not reap immediately; give the kernel time
        Thread.sleep(forTimeInterval: 0.5)

        // After SIGHUP + waitpid, kill(pid, 0) should fail with ESRCH
        let ret = kill(childPID, 0)
        #expect(ret != 0, "Child process should be dead after close()")
    }

    @Test func spawnUsesLoginShellPrefix() throws {
        let pty = try PTY.spawn(cols: 80, rows: 24)
        defer { pty.close() }

        Thread.sleep(forTimeInterval: 0.5)

        // Drain initial prompt output
        var buf = [UInt8](repeating: 0, count: 4096)
        _ = buf.withUnsafeMutableBytes { pty.read(into: $0) }

        pty.write("echo $0\n")
        Thread.sleep(forTimeInterval: 1.0)

        // Read all available output (may come in multiple chunks)
        var allOutput = ""
        for _ in 0..<5 {
            let n = buf.withUnsafeMutableBytes { pty.read(into: $0) }
            if n > 0 {
                allOutput += String(bytes: buf[..<n], encoding: .utf8) ?? ""
            }
            if allOutput.contains("-") { break }
            Thread.sleep(forTimeInterval: 0.2)
        }
        #expect(allOutput.contains("-"), "Shell $0 should contain '-' prefix for login shell")
    }
}
