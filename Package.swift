// swift-tools-version:5.9

//
// This source file is part of the Stanford Spezi open source project
// 
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
// 
// SPDX-License-Identifier: MIT
//

import PackageDescription


let package = Package(
    name: "SpeziBluetooth",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macCatalyst(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "BluetoothServices", targets: ["BluetoothServices"]),
        .library(name: "BluetoothViews", targets: ["BluetoothViews"]),
        .library(name: "SpeziBluetooth", targets: ["SpeziBluetooth"]),
        .library(name: "XCTBluetooth", targets: ["XCTBluetooth"])
    ],
    dependencies: [
        .package(url: "https://github.com/StanfordSpezi/SpeziFoundation", from: "1.0.0"),
        .package(url: "https://github.com/StanfordSpezi/Spezi", from: "1.2.0"),
        .package(url: "https://github.com/StanfordSpezi/SpeziViews", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.59.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.4")
    ],
    targets: [
        .target(
            name: "SpeziBluetooth",
            dependencies: [
                .product(name: "Spezi", package: "Spezi"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOFoundationCompat", package: "swift-nio"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                // We have an issue in Xcode projects when importing XCTBluetooth in a test target that it fails
                // to link with SpeziFoundation. lol. :)
                .product(name: "SpeziFoundation", package: "SpeziFoundation")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "BluetoothServices",
            dependencies: [
                .target(name: "SpeziBluetooth")
            ]
        ),
        .target(
            name: "BluetoothViews",
            dependencies: [
                .target(name: "SpeziBluetooth"),
                .product(name: "SpeziViews", package: "SpeziViews")
            ]
        ),
        .target(
            name: "XCTBluetooth",
            dependencies: [
                .target(name: "SpeziBluetooth"),
                .product(name: "NIO", package: "swift-nio")
            ]
        ),
        .executableTarget(
            name: "TestPeripheral",
            dependencies: [
                .target(name: "SpeziBluetooth"),
                .target(name: "BluetoothServices")
            ]
        ),
        .testTarget(
            name: "SpeziBluetoothTests",
            dependencies: [
                .target(name: "BluetoothServices"),
                .target(name: "SpeziBluetooth"),
                .target(name: "XCTBluetooth"),
                .product(name: "NIO", package: "swift-nio")
            ]
        )
    ]
)
