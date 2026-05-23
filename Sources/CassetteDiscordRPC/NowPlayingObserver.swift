import Foundation
import os

private let logger = Logger(
    subsystem: "fr.mathieu-dubart.cassette-discord-rpc",
    category: "NowPlayingObserver"
)

enum NowPlayingEvent: Sendable {
    case trackChanged(NowPlayingInfo)
    case playbackStopped
}

// NSObjectProtocol tokens from DistributedNotificationCenter are ObjC objects
// whose thread-safety is guaranteed by the center itself.
private struct ObserverToken: @unchecked Sendable {
    let value: any NSObjectProtocol
}

final class NowPlayingObserver: Sendable {

    private static let nowPlayingNotification = "fr.mathieu-dubart.Cassette.nowPlaying"
    private static let playbackStoppedNotification = "fr.mathieu-dubart.Cassette.playbackStopped"

    func events() -> AsyncStream<NowPlayingEvent> {
        AsyncStream { continuation in
            let center = DistributedNotificationCenter.default()

            let nowPlayingToken = ObserverToken(value: center.addObserver(
                forName: NSNotification.Name(Self.nowPlayingNotification),
                object: nil,
                queue: nil
            ) { notification in
                guard
                    let userInfo = notification.userInfo,
                    let title = userInfo["title"] as? String,
                    let artist = userInfo["artist"] as? String,
                    let album = userInfo["album"] as? String,
                    let duration = userInfo["duration"] as? Double,
                    let startedAt = userInfo["startedAt"] as? Double
                else {
                    logger.warning("Received nowPlaying notification with missing or invalid userInfo")
                    return
                }

                let info = NowPlayingInfo(
                    title: title,
                    artist: artist,
                    album: album,
                    duration: duration,
                    startedAt: startedAt
                )
                logger.debug("Track changed event received")
                continuation.yield(.trackChanged(info))
            })

            let stoppedToken = ObserverToken(value: center.addObserver(
                forName: NSNotification.Name(Self.playbackStoppedNotification),
                object: nil,
                queue: nil
            ) { _ in
                logger.debug("Playback stopped event received")
                continuation.yield(.playbackStopped)
            })

            continuation.onTermination = { _ in
                center.removeObserver(nowPlayingToken.value)
                center.removeObserver(stoppedToken.value)
                logger.info("NowPlayingObserver terminated")
            }

            logger.info("NowPlayingObserver started, listening for notifications")
        }
    }
}
