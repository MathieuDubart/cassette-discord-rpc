import Foundation

struct Activity: Encodable {
    struct Args: Encodable {
        struct ActivityPayload: Encodable {
            struct Assets: Encodable {
                var large_image: String?
                var large_text: String?
                let small_image: String
                let small_text: String
            }

            struct Timestamps: Encodable {
                let start: Int
            }

            let details: String
            let state: String
            let assets: Assets
            let timestamps: Timestamps
        }

        let pid: Int
        let activity: ActivityPayload
    }

    let cmd: String
    let args: Args

    static func make(from info: NowPlayingInfo, coverArtURL: String?) -> Activity {
        let assets = Args.ActivityPayload.Assets(
            large_image: coverArtURL,
            large_text: info.album,
            small_image: "https://raw.githubusercontent.com/MathieuDubart/cassette-discord-rpc/main/Assets/cassette-icon.png",
            small_text: "Cassette"
        )
        let timestamps = Args.ActivityPayload.Timestamps(start: Int(info.startedAt))
        let payload = Args.ActivityPayload(
            details: info.title,
            state: "\(info.artist) — \(info.album)",
            assets: assets,
            timestamps: timestamps
        )
        let args = Args(
            pid: Int(ProcessInfo.processInfo.processIdentifier),
            activity: payload
        )
        return Activity(cmd: "SET_ACTIVITY", args: args)
    }
}
