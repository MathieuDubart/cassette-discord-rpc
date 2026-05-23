import Foundation
import os

private let logger = Logger(
    subsystem: "fr.mathieu-dubart.cassette-discord-rpc",
    category: "Main"
)

do {
    let config = try loadConfiguration()
    let daemon = Daemon(config: config)
    await daemon.run()
} catch {
    logger.error("Startup failed: \(error.localizedDescription, privacy: .public)")
    exit(1)
}
