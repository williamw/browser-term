import Darwin
import Foundation

final class PTY: Sendable {
    let masterFD: Int32
    let childPID: pid_t

    enum PTYError: Error {
        case forkFailed
        case resizeFailed
    }

    private init(masterFD: Int32, childPID: pid_t) {
        self.masterFD = masterFD
        self.childPID = childPID
    }

    /// Spawn a new PTY with the given shell as a login shell.
    static func spawn(shell: String? = nil, cols: UInt16, rows: UInt16) throws -> PTY {
        let shellPath = shell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/sh"

        var ws = winsize(ws_row: rows, ws_col: cols, ws_xpixel: 0, ws_ypixel: 0)
        var masterFD: Int32 = -1

        let pid = forkpty(&masterFD, nil, nil, &ws)
        guard pid >= 0 else { throw PTYError.forkFailed }

        if pid == 0 {
            // ── Child process ── pure C calls only, no Swift objects ──

            // Build login shell name: "-basename"
            let basename = shellPath.split(separator: "/").last.map(String.init) ?? shellPath
            let loginName = "-" + basename

            // Set environment
            setenv("TERM", "xterm-256color", 1)
            setenv("COLORTERM", "truecolor", 1)
            setenv("LANG", "en_US.UTF-8", 1)

            // Default to user's home directory
            if let home = getenv("HOME") {
                chdir(home)
            }

            // Execute shell as login shell
            loginName.withCString { loginNameC in
                shellPath.withCString { shellC in
                    var argv: [UnsafeMutablePointer<CChar>?] = [
                        UnsafeMutablePointer(mutating: loginNameC),
                        nil,
                    ]
                    execvp(shellC, &argv)
                }
            }
            _exit(127)
        }

        return PTY(masterFD: masterFD, childPID: pid)
    }

    /// Read available output from the PTY master.
    func read(into buffer: UnsafeMutableRawBufferPointer) -> Int {
        let n = Darwin.read(masterFD, buffer.baseAddress!, buffer.count)
        if n < 0 {
            // EIO means child exited — treat as EOF
            return 0
        }
        return n
    }

    /// Write input to the PTY master. Handles partial writes.
    func write(_ data: [UInt8]) {
        var total = 0
        while total < data.count {
            let n = data.withUnsafeBufferPointer { buf in
                Darwin.write(masterFD, buf.baseAddress! + total, data.count - total)
            }
            if n <= 0 { return }
            total += n
        }
    }

    /// Write a string to the PTY master.
    func write(_ string: String) {
        write(Array(string.utf8))
    }

    /// Resize the PTY to new dimensions.
    func resize(cols: UInt16, rows: UInt16) throws {
        var ws = winsize(ws_row: rows, ws_col: cols, ws_xpixel: 0, ws_ypixel: 0)
        guard ioctl(masterFD, TIOCSWINSZ, &ws) == 0 else {
            throw PTYError.resizeFailed
        }
    }

    /// Create an AsyncStream that reads from this PTY's master fd.
    func outputStream() -> AsyncStream<Data> {
        let fd = masterFD
        return AsyncStream { continuation in
            let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global())
            source.setEventHandler {
                var buf = [UInt8](repeating: 0, count: 4096)
                let n = Darwin.read(fd, &buf, buf.count)
                if n <= 0 {
                    continuation.finish()
                    source.cancel()
                    return
                }
                continuation.yield(Data(buf[..<n]))
            }
            source.setCancelHandler {
                continuation.finish()
            }
            continuation.onTermination = { _ in
                source.cancel()
            }
            source.resume()
        }
    }

    /// Close the PTY: kill child process and close file descriptor.
    func close() {
        kill(childPID, SIGHUP)
        Darwin.close(masterFD)
        // Non-blocking reap; if child hasn't exited yet, try SIGKILL
        var status: Int32 = 0
        if waitpid(childPID, &status, WNOHANG) == 0 {
            kill(childPID, SIGKILL)
            waitpid(childPID, &status, 0)
        }
    }

    deinit {
        close()
    }
}
