import Foundation
import os

private let logger = Logger(
    subsystem: "fr.mathieu-dubart.cassette-discord-rpc",
    category: "Configuration"
)

struct Configuration: Decodable, Sendable {
    let clientId: String
    let port: UInt16

    private enum CodingKeys: String, CodingKey {
        case clientId, port
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clientId = try container.decode(String.self, forKey: .clientId)
        port = try container.decodeIfPresent(UInt16.self, forKey: .port) ?? 47832
    }
}

enum ConfigurationError: Error {
    case fileNotFound(String)
    case decodingFailed(Error)
}

func loadConfiguration() throws -> Configuration {
    let configURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".config/cassette-discord-rpc/config.json")

    guard FileManager.default.fileExists(atPath: configURL.path) else {
        logger.error("Configuration file not found at ~/.config/cassette-discord-rpc/config.json")
        throw ConfigurationError.fileNotFound(configURL.path)
    }

    do {
        let data = try Data(contentsOf: configURL)
        let config = try JSONDecoder().decode(Configuration.self, from: data)
        logger.info("Configuration loaded successfully")
        return config
    } catch let error as DecodingError {
        logger.error("Failed to decode configuration: \(error.localizedDescription, privacy: .public)")
        throw ConfigurationError.decodingFailed(error)
    }
}
