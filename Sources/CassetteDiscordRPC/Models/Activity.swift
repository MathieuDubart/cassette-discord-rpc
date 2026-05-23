import Foundation

struct Activity: Encodable {
    struct Args: Encodable {
        struct ActivityPayload: Encodable {
            struct Assets: Encodable {
                let large_image: String?
                let small_image: String
                let small_text: String

                private enum CodingKeys: String, CodingKey {
                    case large_image, small_image, small_text
                }

                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    try container.encodeIfPresent(large_image, forKey: .large_image)
                    try container.encode(small_image, forKey: .small_image)
                    try container.encode(small_text, forKey: .small_text)
                }
            }

            struct Timestamps: Encodable {
                let start: Int
            }

            struct Button: Encodable {
                let label: String
                let url: String
            }

            let name: String
            let details: String
            let state: String
            let assets: Assets
            let timestamps: Timestamps
            let buttons: [Button]
            let type: Int
        }

        let pid: Int
        let activity: ActivityPayload
    }

    let cmd: String
    let args: Args

    static func make(from info: NowPlayingInfo, coverArtURL: String?) -> Activity {
        let assets = Args.ActivityPayload.Assets(
            large_image: coverArtURL,
            small_image: "cassette-icon",
            small_text: "Cassette"
        )
        let timestamps = Args.ActivityPayload.Timestamps(start: Int(info.startedAt))
        let buttons = [Args.ActivityPayload.Button(label: "Get Cassette", url: "https://getcassette.app")]
        let payload = Args.ActivityPayload(
            name: "\(info.title) - \(info.artist)",
            details: "\(info.album)",
            state: "on Cassette",
            assets: assets,
            timestamps: timestamps,
            buttons: buttons,
            type: 2
        )
        let args = Args(
            pid: Int(ProcessInfo.processInfo.processIdentifier),
            activity: payload
        )
        return Activity(cmd: "SET_ACTIVITY", args: args)
    }
}
