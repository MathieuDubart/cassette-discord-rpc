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

    init(config: Configuration) {
        self.config = config
        self.ipcClient = DiscordIPCClient(clientId: config.clientId)
        self.musicBrainz = MusicBrainzClient()
        self.server = HTTPServer(port: config.port)
    }

    func run() async {
        logger.info("Daemon starting")

        await ipcClient.connect()
        logger.info("Connected to Discord IPC")

        let events = await server.start()
        logger.info("HTTP server listening on localhost:\(self.config.port, privacy: .public)")

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
        let coverArtURL = await musicBrainz.coverArtURL(artist: info.artist, album: info.album)
        let activity = Activity.make(from: info, coverArtURL: coverArtURL)
        await ipcClient.setActivity(activity)
    }

    private func handlePlaybackStopped() async {
        logger.info("Handling playback stop, clearing Discord activity")
        await ipcClient.clearActivity()
    }
}
