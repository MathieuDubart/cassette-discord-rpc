import Foundation

struct Activity: Encodable {
    struct Args: Encodable {
        struct ActivityPayload: Encodable {
            struct Assets: Encodable {
                let large_image: String?
                let large_text: String
                let small_image: String
                let small_text: String

                private enum CodingKeys: String, CodingKey {
                    case large_image, large_text, small_image, small_text
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encodeIfPresent(large_image, forKey: .large_image)
                    try container.encode(large_text, forKey: .large_text)
                    try container.encode(small_image, forKey: .small_image)
                    try container.encode(small_text, forKey: .small_text)
                }
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
            details: "\(info.title) - \(info.artist)",
            state: "Sur Cassette",
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
