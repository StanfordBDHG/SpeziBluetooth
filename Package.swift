// swift-tools-version:6.0

//
// This source file is part of the Stanford Spezi open source project
// 
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
// 
// SPDX-License-Identifier: MIT
//

import class Foundation.ProcessInfo
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
        .library(name: "SpeziBluetoothServices", targets: ["SpeziBluetoothServices"]),
        .library(name: "SpeziBluetooth", targets: ["SpeziBluetooth"])
    ],
    dependencies: [
        .package(url: "https://github.com/StanfordSpezi/SpeziFoundation.git", branch: "feature/concurrency-infrastructure"),
        .package(url: "https://github.com/StanfordSpezi/Spezi.git", from: "1.7.1"),
        .package(url: "https://github.com/StanfordSpezi/SpeziViews.git", branch: "feature/additional-infrastructure"),
        .package(url: "https://github.com/StanfordSpezi/SpeziNetworking.git", from: "2.1.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.59.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.4"),
        .package(url: "https://github.com/apple/swift-atomics.git", from: "1.2.0"),
        .package(url: "https://github.com/StanfordBDHG/XCTestExtensions.git", from: "1.0.0")
    ] + swiftLintPackage(),
    targets: [
        .target(
            name: "SpeziBluetooth",
            dependencies: [
                .product(name: "Spezi", package: "Spezi"),
                .product(name: "SpeziViews", package: "SpeziViews"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "SpeziFoundation", package: "SpeziFoundation"),
                .product(name: "ByteCoding", package: "SpeziNetworking"),
                .product(name: "Atomics", package: "swift-atomics")
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5) // see https://github.com/swiftlang/swift/issues/76005
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .target(
            name: "SpeziBluetoothServices",
            dependencies: [
                .target(name: "SpeziBluetooth"),
                .product(name: "ByteCoding", package: "SpeziNetworking"),
                .product(name: "SpeziNumerics", package: "SpeziNetworking")
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .executableTarget(
            name: "TestPeripheral",
            dependencies: [
                .target(name: "SpeziBluetooth"),
                .target(name: "SpeziBluetoothServices"),
                .product(name: "ByteCoding", package: "SpeziNetworking")
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .testTarget(
            name: "SpeziBluetoothTests",
            dependencies: [
                .target(name: "SpeziBluetooth"),
                .target(name: "SpeziBluetoothServices")
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .testTarget(
            name: "SpeziBluetoothServicesTests",
            dependencies: [
                .target(name: "SpeziBluetooth"),
                .target(name: "SpeziBluetoothServices"),
                .product(name: "XCTByteCoding", package: "SpeziNetworking"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "XCTestExtensions", package: "XCTestExtensions")
            ],
            plugins: [] + swiftLintPlugin()
        )
    ]
)


func swiftLintPlugin() -> [Target.PluginUsage] {
    // Fully quit Xcode and open again with `open --env SPEZI_DEVELOPMENT_SWIFTLINT /Applications/Xcode.app`
    if ProcessInfo.processInfo.environment["SPEZI_DEVELOPMENT_SWIFTLINT"] != nil {
        [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")]
    } else {
        []
    }
}

func swiftLintPackage() -> [PackageDescription.Package.Dependency] {
    if ProcessInfo.processInfo.environment["SPEZI_DEVELOPMENT_SWIFTLINT"] != nil {
        [.package(url: "https://github.com/realm/SwiftLint.git", from: "0.55.1")]
    } else {
        []
    }
}
