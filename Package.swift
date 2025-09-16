// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "WLStorage",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
    ],
    products: [
        .library(
            name: "WLStorage",
            targets: ["WLStorage"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.10.0"),
    ],
    targets: [
        .target(
            name: "WLStorage"),
        .testTarget(
            name: "WLStorageTests",
            dependencies: ["ViewInspector", "WLStorage"]
        ),
    ]
)
