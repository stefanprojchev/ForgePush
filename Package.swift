// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "ForgePush",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "ForgePushPermission", targets: ["ForgePushPermission"]),
        .library(name: "ForgePushToken", targets: ["ForgePushToken"]),
        .library(name: "ForgeSilentPush", targets: ["ForgeSilentPush"]),
        .library(name: "ForgeVisiblePush", targets: ["ForgeVisiblePush"]),
        .library(name: "ForgePush", targets: ["ForgePush"]),
    ],
    dependencies: [
        .package(url: "https://github.com/stefanprojchev/ForgeCore.git", from: "1.0.0"),
        .package(url: "https://github.com/stefanprojchev/ForgeObservers.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "ForgePushPermission"),
        .target(
            name: "ForgePushToken",
            dependencies: [
                .product(name: "ForgeCore", package: "ForgeCore"),
            ]
        ),
        .target(
            name: "ForgeSilentPush",
            dependencies: [
                .product(name: "ForgeCore", package: "ForgeCore"),
                .product(name: "ForgeObservers", package: "ForgeObservers"),
            ]
        ),
        .target(
            name: "ForgeVisiblePush",
            dependencies: [
                .product(name: "ForgeCore", package: "ForgeCore"),
                .product(name: "ForgeObservers", package: "ForgeObservers"),
            ]
        ),
        .target(
            name: "ForgePush",
            dependencies: [
                "ForgePushPermission",
                "ForgePushToken",
                "ForgeSilentPush",
                "ForgeVisiblePush",
            ]
        ),
        .testTarget(name: "ForgePushTokenTests", dependencies: ["ForgePushToken"]),
        .testTarget(name: "ForgeSilentPushTests", dependencies: ["ForgeSilentPush"]),
        .testTarget(name: "ForgeVisiblePushTests", dependencies: ["ForgeVisiblePush"]),
    ],
    swiftLanguageModes: [.v6]
)
