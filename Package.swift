// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LastFM",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "LastFM", path: "Sources"),
        .testTarget(name: "LastFMTests", dependencies: ["LastFM"], path: "Tests/LastFMTests")
    ]
)
