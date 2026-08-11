// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Flashnotes",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Flashnotes", targets: ["Flashnotes"])],
    targets: [
        .executableTarget(
            name: "Flashnotes",
            path: "Sources/Flashnotes",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "FlashnotesTests",
            dependencies: ["Flashnotes"],
            path: "Tests/FlashnotesTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
