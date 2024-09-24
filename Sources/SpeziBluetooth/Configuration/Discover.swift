//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


import SpeziViews
struct DeviceVariant {
    // TODO: optional descriptor (e.g., also the name!)
    let name: String
    let icon: ImageReference? // TODO: automtic "sensor" default?
}


/// Declare how a bluetooth device is discovered.
///
/// Declares by which ``DiscoveryCriteria`` a given ``BluetoothDevice`` implementation is discovered.
///
/// - Important: The discovery criteria must be unique across all discovery configurations. Not doing so will result in undefined behavior.
///
/// ## Topics
///
/// ### Discovering a device
///
/// - ``init(_:by:)``
///
/// ### Semantic Model
/// - ``DeviceDiscoveryDescriptor``
/// - ``DiscoveryDescriptorBuilder``
public struct Discover<Device: BluetoothDevice> {
    let deviceType: Device.Type
    let discoveryCriteria: DiscoveryCriteria

    let variants: [DeviceVariant]

    /// Create a discovery for a given device type.
    /// - Parameters:
    ///   - device: The type of a ``BluetoothDevice`` implementation.
    ///   - discoveryCriteria: The criteria by which the device is discovered.
    public init(_ device: Device.Type, by discoveryCriteria: DiscoveryCriteria) {
        self.deviceType = device
        self.discoveryCriteria = discoveryCriteria

        self.variants = [DeviceVariant(name: "\(Device.self)", icon: .system("sensor"))]
    }

    public init(_ device: Device.Type, by discoveryCriteria: DiscoveryCriteria, @DeviceApperanceBuilder appearance: () -> DeviceAppearance) {
        self.deviceType = device
        self.discoveryCriteria = discoveryCriteria

        // TODO: update
        self.variants = [DeviceVariant(name: "\(Device.self)", icon: .system("sensor"))]
    }

    // TODO: options closure to define
    //  -> Asset/Appearance whatever (Name + ImageReference?), otherwise we use the default type name and sensor image
    // TODO: "Variant" to declare another (at least one!) discovery criteria and then the asset/apperance!
}


extension Discover: Sendable {}

// TODO: remove
func test() {
    final class Device2: BluetoothDevice {}
    _ = Discover(Device2.self, by: .advertisedService("asdf")) {
        DeviceAppearance(name: "MyDevice")
        // TODO: DeviceAppearance(name: "MyDevice")
    }
}
