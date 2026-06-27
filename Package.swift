// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CyberTranslate",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "CyberTranslate",
            path: "Sources/CyberTranslate",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
