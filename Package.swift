// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "WLStorage",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "WLStorage",
            targets: ["WLStorage"])
    ],
    targets: [
        .target(
            name: "WLStorage"),
        .testTarget(
            name: "WLStorageTests",
            dependencies: ["WLStorage"]
        )
    ]
)
