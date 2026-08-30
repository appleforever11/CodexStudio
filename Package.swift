// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexStudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexStudio", targets: ["CodexStudio"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.9.6")
    ],
    targets: [
        .executableTarget(
            name: "CodexStudio",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/CodexStudio"
        )
    ]
)
