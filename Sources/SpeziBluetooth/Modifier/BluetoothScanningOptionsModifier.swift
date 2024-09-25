//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


import SwiftUI


private struct BluetoothScanningOptionsModifier: ViewModifier {
    private let minimumRSSI: Int?
    private let advertisementStaleInterval: TimeInterval?

    @Environment(\.minimumRSSI)
    private var parentMinimumRSSI
    @Environment(\.advertisementStaleInterval)
    private var parentAdvertisementStaleInterval

    init(minimumRSSI: Int?, advertisementStaleInterval: TimeInterval?) {
        self.minimumRSSI = minimumRSSI
        self.advertisementStaleInterval = advertisementStaleInterval
    }


    func body(content: Content) -> some View {
        content
            .environment(\.minimumRSSI, minimumRSSI ?? parentMinimumRSSI)
            .environment(\.advertisementStaleInterval, advertisementStaleInterval ?? parentAdvertisementStaleInterval)
    }
}


extension View {
    /// Define bluetooth scanning options in the view hierarchy.
    ///
    /// This view modifier can be used to set scanning options for the view hierarchy.
    /// This will overwrite values passed to modifiers like
    /// ``SwiftUICore/View/scanNearbyDevices(enabled:with:discovery:minimumRSSI:advertisementStaleInterval:autoConnect:)``.
    ///
    /// ## Topics
    /// ### Accessing Scanning Options
    /// - ``SwiftUICore/EnvironmentValues/minimumRSSI``
    /// - ``SwiftUICore/EnvironmentValues/advertisementStaleInterval``
    ///
    /// - Parameters:
    ///   - minimumRSSI: The minimum rssi a nearby peripheral must have to be considered nearby. Supply `nil` to use default the default value or a value from the environment.
    ///   - advertisementStaleInterval: The time interval after which a peripheral advertisement is considered stale
    ///     if we don't hear back from the device. Minimum is 1 second. Supply `nil` to use default the default value or a value from the environment.
    public func bluetoothScanningOptions(minimumRSSI: Int? = nil, advertisementStaleInterval: TimeInterval? = nil) -> some View {
        modifier(BluetoothScanningOptionsModifier(minimumRSSI: minimumRSSI, advertisementStaleInterval: advertisementStaleInterval))
    }
}
