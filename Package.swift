// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "InputVoice",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "InputVoice",
            path: "Sources/InputVoice",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Speech"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Carbon"),
            ]
        )
    ]
)
