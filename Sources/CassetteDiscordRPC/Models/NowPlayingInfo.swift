struct NowPlayingInfo: Sendable, Decodable {
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let startedAt: Double
}
