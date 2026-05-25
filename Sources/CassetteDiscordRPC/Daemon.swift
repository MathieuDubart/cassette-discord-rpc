import Foundation
import os

private let logger = Logger(
    subsystem: "fr.mathieu-dubart.cassette-discord-rpc",
    category: "Daemon"
)

actor Daemon {

    private let config: Configuration
    private let ipcClient: DiscordIPCClient
    private let musicBrainz: MusicBrainzClient
    private let server: HTTPServer
    private var inactivityTask: Task<Void, Never>?

    init(config: Configuration) {
        self.config = config
        self.ipcClient = DiscordIPCClient(clientId: config.clientId)
        self.musicBrainz = MusicBrainzClient()
        self.server = HTTPServer(port: config.port)
    }

    func run() async {
        logger.info("Daemon starting")

        // Start HTTP server immediately
        let events = await server.start()
        logger.info("HTTP server started on localhost:\(self.config.port, privacy: .public)")

        // Connect to Discord IPC in background (retries independently)
        Task {
            await ipcClient.connect()
        }

        for await event in events {
            switch event {
            case .trackChanged(let info):
                await handleTrackChanged(info)
            case .playbackStopped:
                await handlePlaybackStopped()
            }
        }
    }

    private func handleTrackChanged(_ info: NowPlayingInfo) async {
        logger.info("Handling track change")
        resetInactivityTimer()
        let coverArtURL = await musicBrainz.coverArtURL(artist: info.artist, album: info.album)
        let activity = Activity.make(from: info, coverArtURL: coverArtURL)
        await ipcClient.setActivity(activity)
    }

    private func handlePlaybackStopped() async {
        logger.info("Handling playback stop, clearing Discord activity")
        resetInactivityTimer()
        await ipcClient.clearActivity()
    }

    private func resetInactivityTimer() {
        inactivityTask?.cancel()
        inactivityTask = Task {
            do {
                try await Task.sleep(for: .seconds(5 * 60))
                logger.info("No activity for 5 minutes, clearing Discord presence")
                await ipcClient.clearActivity()
            } catch {
                // Cancelled — a new event arrived before the timeout
            }
        }
    }
}
