// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexStudio",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CodexStudio", targets: ["CodexStudio"]),
        .executable(name: "CodexStudioThemeHelper", targets: ["CodexStudioThemeHelper"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.9.6")
    ],
    targets: [
        .executableTarget(name: "CodexStudioThemeHelper", path: "Sources/CodexStudioThemeHelper"),
        .executableTarget(
            name: "CodexStudio",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/CodexStudio"
        ),
        .testTarget(
            name: "CodexStudioTests",
            dependencies: ["CodexStudio"],
            path: "Tests/CodexStudioTests"
        )
    ]
)
