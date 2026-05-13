// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NotifiableKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v14),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "NotifiableKit", targets: ["NotifiableKit"])
    ],
    targets: [
        .target(
            name: "NotifiableKit",
            path: "NotifiableKit/Sources/NotifiableKit"
        ),
        .testTarget(
            name: "NotifiableKitTests",
            dependencies: ["NotifiableKit"],
            path: "NotifiableKit/Tests/NotifiableKitTests"
        )
    ]
)
