import Foundation
import Network
import Synchronization

final class WebSocketServer: Sendable {
    let listener: NWListener
    let sessionManager: SessionManager
    private let connections = Mutex<[ObjectIdentifier: WebSocketConnection]>([:])

    init(port: UInt16, sessionManager: SessionManager) throws {
        self.sessionManager = sessionManager

        let params = NWParameters.tcp
        let wsOptions = NWProtocolWebSocket.Options()
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        self.listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener.parameters.requiredLocalEndpoint = .hostPort(
            host: .ipv4(.loopback),
            port: NWEndpoint.Port(rawValue: port)!
        )
    }

    func start() {
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                NSLog("terminatab-server listening on ws://127.0.0.1:%d",
                      self.listener.port?.rawValue ?? 0)
            case .failed(let error):
                NSLog("Server failed: %@", error.localizedDescription)
            default:
                break
            }
        }

        listener.newConnectionHandler = { [self] nwConnection in
            let conn = WebSocketConnection(
                connection: nwConnection,
                sessionManager: sessionManager
            )
            let id = ObjectIdentifier(conn)
            connections.withLock { $0[id] = conn }
            conn.onClose = { [weak self] in
                self?.connections.withLock { _ = $0.removeValue(forKey: id) }
            }
            conn.start()
        }

        listener.start(queue: .global())

        // Start cleanup timer
        Task {
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(5))
                await sessionManager.cleanup()
            }
        }
    }

    func stop() {
        listener.cancel()
    }
}
