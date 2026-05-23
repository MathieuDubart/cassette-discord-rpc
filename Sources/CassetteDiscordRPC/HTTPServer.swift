import Foundation
import Network
import os

private let logger = Logger(
    subsystem: "fr.mathieu-dubart.cassette-discord-rpc",
    category: "HTTPServer"
)

enum NowPlayingEvent: Sendable {
    case trackChanged(NowPlayingInfo)
    case playbackStopped
}

actor HTTPServer {

    private let port: UInt16
    private var eventContinuation: AsyncStream<NowPlayingEvent>.Continuation?
    private var listener: NWListener?

    init(port: UInt16) {
        self.port = port
    }

    func start() -> AsyncStream<NowPlayingEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: NowPlayingEvent.self)
        eventContinuation = continuation
        startListening()
        return stream
    }

    private func startListening() {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            logger.error("Invalid port number: \(self.port, privacy: .public)")
            return
        }

        let newListener: NWListener
        do {
            newListener = try NWListener(using: .tcp, on: nwPort)
        } catch {
            logger.error("Failed to create HTTP listener: \(error.localizedDescription, privacy: .public)")
            return
        }

        listener = newListener

        newListener.newConnectionHandler = { [self] connection in
            Task {
                await self.handleConnection(connection)
            }
        }

        let capturedPort = port
        newListener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                logger.info("HTTP server listening on port \(capturedPort, privacy: .public)")
            case .failed(let error):
                logger.error("HTTP server failed: \(error.localizedDescription, privacy: .public)")
            case .waiting(let error):
                logger.warning("HTTP server waiting: \(error.localizedDescription, privacy: .public)")
            default:
                break
            }
        }

        newListener.start(queue: .global(qos: .userInitiated))
    }

    private func handleConnection(_ connection: NWConnection) async {
        connection.start(queue: .global(qos: .userInitiated))

        guard let raw = await receiveRequest(from: connection),
              let text = String(data: raw, encoding: .utf8),
              let sepRange = text.range(of: "\r\n\r\n") else {
            await respond(400, on: connection)
            return
        }

        let headerSection = String(text[text.startIndex..<sepRange.lowerBound])
        let bodyText = String(text[sepRange.upperBound...])

        let requestLines = headerSection.components(separatedBy: "\r\n")
        guard let requestLine = requestLines.first else {
            await respond(400, on: connection)
            return
        }

        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2, parts[0] == "POST" else {
            await respond(400, on: connection)
            return
        }

        let path = String(parts[1])
        let bodyData = Data(bodyText.utf8)

        switch path {
        case "/now-playing":
            do {
                let info = try JSONDecoder().decode(NowPlayingInfo.self, from: bodyData)
                eventContinuation?.yield(.trackChanged(info))
                await respond(200, on: connection)
            } catch {
                logger.warning("Invalid /now-playing body: \(error.localizedDescription, privacy: .public)")
                await respond(400, on: connection)
            }

        case "/playback-stopped":
            eventContinuation?.yield(.playbackStopped)
            await respond(200, on: connection)

        default:
            logger.warning("Unknown endpoint: \(path, privacy: .public)")
            await respond(400, on: connection)
        }
    }

    private func receiveRequest(from connection: NWConnection) async -> Data? {
        var buffer = Data()
        let terminator = Data("\r\n\r\n".utf8)

        while buffer.range(of: terminator) == nil {
            guard let chunk = await receiveChunk(from: connection), !chunk.isEmpty else {
                return nil
            }
            buffer.append(chunk)
        }

        guard
            let terminatorRange = buffer.range(of: terminator),
            let headerText = String(data: buffer, encoding: .utf8)
        else { return nil }

        var contentLength = 0
        for line in headerText.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix("content-length:") {
                let rawValue = line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)
                contentLength = Int(rawValue) ?? 0
                break
            }
        }

        var remaining = contentLength - (buffer.count - terminatorRange.upperBound)
        while remaining > 0 {
            guard let chunk = await receiveChunk(from: connection), !chunk.isEmpty else { break }
            buffer.append(chunk)
            remaining -= chunk.count
        }

        return buffer
    }

    private func receiveChunk(from connection: NWConnection) async -> Data? {
        await withCheckedContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, _, error in
                if error != nil {
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: data ?? Data())
                }
            }
        }
    }

    private func respond(_ statusCode: Int, on connection: NWConnection) async {
        let phrase = statusCode == 200 ? "OK" : "Bad Request"
        let response = Data("HTTP/1.1 \(statusCode) \(phrase)\r\nContent-Length: 0\r\n\r\n".utf8)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            connection.send(content: response, completion: .contentProcessed { _ in
                connection.cancel()
                continuation.resume()
            })
        }
    }
}
