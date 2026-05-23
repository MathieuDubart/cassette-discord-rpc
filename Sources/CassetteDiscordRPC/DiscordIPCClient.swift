import Foundation
import Network
import os

private let logger = Logger(
    subsystem: "fr.mathieu-dubart.cassette-discord-rpc",
    category: "DiscordIPCClient"
)

private enum Opcode: UInt32 {
    case handshake = 0
    case frame = 1
    case close = 2
    case ping = 3
    case pong = 4
}

actor DiscordIPCClient {

    private let clientId: String
    private var connection: NWConnection?
    private var isConnected = false
    private var retryDelay: UInt64 = 5_000_000_000
    private static let maxRetryDelay: UInt64 = 30_000_000_000

    init(clientId: String) {
        self.clientId = clientId
    }

    func connect() async {
        while true {
            if let conn = tryConnect() {
                connection = conn
                await performHandshake(on: conn)
                if isConnected {
                    retryDelay = 5_000_000_000
                    return
                }
            }
            logger.warning("Discord IPC connection failed, retrying in \(self.retryDelay / 1_000_000_000)s")
            try? await Task.sleep(nanoseconds: retryDelay)
            retryDelay = min(retryDelay * 2, Self.maxRetryDelay)
        }
    }

    func setActivity(_ activity: Activity) async {
        guard isConnected, let conn = connection else {
            logger.warning("Cannot set activity: not connected to Discord IPC")
            return
        }

        struct Nonce: Encodable {}
        struct Wrapper: Encodable {
            let cmd: String
            let args: Activity.Args
            let nonce: String
        }

        let wrapper = Wrapper(
            cmd: activity.cmd,
            args: activity.args,
            nonce: UUID().uuidString
        )

        guard let data = try? JSONEncoder().encode(wrapper) else { return }
        await send(opcode: .frame, payload: data, on: conn)
    }

    func clearActivity() async {
        guard isConnected, let conn = connection else { return }

        struct ClearArgs: Encodable {
            let pid: Int
        }
        struct ClearPayload: Encodable {
            let cmd: String
            let args: ClearArgs
            let nonce: String
        }

        let payload = ClearPayload(
            cmd: "SET_ACTIVITY",
            args: ClearArgs(pid: Int(ProcessInfo.processInfo.processIdentifier)),
            nonce: UUID().uuidString
        )

        guard let data = try? JSONEncoder().encode(payload) else { return }
        await send(opcode: .frame, payload: data, on: conn)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
        logger.info("Disconnected from Discord IPC")
    }

    private func tryConnect() -> NWConnection? {
        for i in 0...9 {
            let path = "/tmp/discord-ipc-\(i)"
            guard FileManager.default.fileExists(atPath: path) else { continue }

            let endpoint = NWEndpoint.unix(path: path)
            let conn = NWConnection(to: endpoint, using: .tcp)
            logger.info("Attempting Discord IPC connection on socket \(i, privacy: .public)")
            return conn
        }
        logger.warning("No Discord IPC socket found in /tmp/discord-ipc-0..9")
        return nil
    }

    private func performHandshake(on connection: NWConnection) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    Task {
                        await self.sendHandshake(on: connection)
                        await self.setIsConnected(true)
                        continuation.resume()
                    }
                case .failed(let error):
                    logger.error("Discord IPC connection failed: \(error.localizedDescription, privacy: .public)")
                    Task {
                        await self.setIsConnected(false)
                        continuation.resume()
                    }
                case .cancelled:
                    Task {
                        await self.setIsConnected(false)
                        continuation.resume()
                    }
                default:
                    break
                }
            }
            connection.start(queue: .global())
        }
    }

    private func setIsConnected(_ value: Bool) {
        isConnected = value
    }

    private func sendHandshake(on connection: NWConnection) async {
        struct Handshake: Encodable {
            let v: Int
            let client_id: String
        }
        let handshake = Handshake(v: 1, client_id: clientId)
        guard let data = try? JSONEncoder().encode(handshake) else { return }
        await send(opcode: .handshake, payload: data, on: connection)
        logger.info("Discord IPC handshake sent")
    }

    private func send(opcode: Opcode, payload: Data, on connection: NWConnection) async {
        var header = Data(count: 8)
        let op = opcode.rawValue.littleEndian
        let length = UInt32(payload.count).littleEndian
        withUnsafeBytes(of: op) { header.replaceSubrange(0..<4, with: $0) }
        withUnsafeBytes(of: length) { header.replaceSubrange(4..<8, with: $0) }

        let message = header + payload

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.send(content: message, completion: .contentProcessed { error in
                if let error {
                    logger.error("Discord IPC send error: \(error.localizedDescription, privacy: .public)")
                    Task { await self.setIsConnected(false) }
                }
                continuation.resume()
            })
        }
    }
}
