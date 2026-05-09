// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotifiableAIKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "NotifiableAIKit", targets: ["NotifiableAIKit"])
    ],
    targets: [
        .target(name: "NotifiableAIKit"),
        .testTarget(name: "NotifiableAIKitTests", dependencies: ["NotifiableAIKit"])
    ]
)
