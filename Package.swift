// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PifagorSwitcher",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "PifagorSwitcherCore", targets: ["PifagorSwitcherCore"]),
        .executable(name: "PifagorSwitcher", targets: ["PifagorSwitcher"]),
        .executable(name: "PifagorSwitcherCoreSpec", targets: ["PifagorSwitcherCoreSpec"])
    ],
    targets: [
        .target(
            name: "PifagorSwitcherCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .executableTarget(
            name: "PifagorSwitcher",
            dependencies: ["PifagorSwitcherCore"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "PifagorSwitcherCoreSpec",
            dependencies: ["PifagorSwitcherCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "PifagorSwitcherCoreTests",
            dependencies: ["PifagorSwitcherCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
