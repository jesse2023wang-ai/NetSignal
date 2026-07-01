// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NetSignal",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NetSignal", targets: ["NetSignal"])
    ],
    targets: [
        .executableTarget(
            name: "NetSignal"
        )
    ]
)
