// swift-tools-version:5.9

//
// This source file is part of the Stanford Spezi open source project
// 
// SPDX-FileCopyrightText: 2022 Stanford University and the project authors (see CONTRIBUTORS.md)
// 
// SPDX-License-Identifier: MIT
//

import class Foundation.ProcessInfo
import PackageDescription


#if swift(<6)
let swiftConcurrency: SwiftSetting = .enableExperimentalFeature("SwiftConcurrency")
#else
let swiftConcurrency: SwiftSetting = .enableUpcomingFeature("SwiftConcurrency")
#endif


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
        .package(url: "https://github.com/StanfordSpezi/SpeziFoundation", from: "1.1.0"),
        .package(url: "https://github.com/StanfordSpezi/Spezi", from: "1.5.0"),
        .package(url: "https://github.com/StanfordSpezi/SpeziNetworking", from: "2.1.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.59.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.4"),
        .package(url: "https://github.com/StanfordBDHG/XCTestExtensions.git", from: "0.4.11")
    ] + swiftLintPackage(),
    targets: [
        .target(
            name: "SpeziBluetooth",
            dependencies: [
                .product(name: "Spezi", package: "Spezi"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "SpeziFoundation", package: "SpeziFoundation"),
                .product(name: "ByteCoding", package: "SpeziNetworking")
            ],
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                swiftConcurrency
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
            swiftSettings: [
                swiftConcurrency
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
            swiftSettings: [
                swiftConcurrency
            ],
            plugins: [] + swiftLintPlugin()
        ),
        .testTarget(
            name: "BluetoothServicesTests",
            dependencies: [
                .target(name: "SpeziBluetoothServices"),
                .target(name: "SpeziBluetooth"),
                .product(name: "XCTByteCoding", package: "SpeziNetworking"),
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "XCTestExtensions", package: "XCTestExtensions")
            ],
            swiftSettings: [
                swiftConcurrency
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
        [.package(url: "https://github.com/realm/SwiftLint.git", .upToNextMinor(from: "0.55.1"))]
    } else {
        []
    }
}
