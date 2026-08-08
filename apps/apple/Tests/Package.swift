// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "App",
    platforms: [.macOS(.v15)],
    targets: [
        .target(
            name: "App",
            path: "App",
            exclude: ["Assets.xcassets", "Config", "Resources", "UI"],
            sources: [
                "Playback/AudioPlayerEngine.swift",
                "Playback/AlbumLibrary.swift",
                "Playback/PlaybackController.swift",
                "Playback/PlaybackMediaRemoteBridge.swift",
                "Playback/PlaybackTrack.swift",
                "Playback/PlaylistLoader.swift",
            ],
            swiftSettings: [.swiftLanguageMode(.v5)],
        ),
        .testTarget(name: "AppTests", dependencies: ["App"], path: "Tests", exclude: ["Package.swift"]),
    ]
)
