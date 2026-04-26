// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NovelForge",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "NovelForge",
            targets: ["NovelForge"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "NovelForge",
            path: "Sources/NovelForge"
        )
    ]
)