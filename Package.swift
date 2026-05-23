// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CassetteDiscordRPC",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CassetteDiscordRPC",
            path: "Sources/CassetteDiscordRPC"
        )
    ]
)
