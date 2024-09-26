//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Describes how to discover a given `BluetoothDevice`.
///
/// Provides a strategy on how to discovery given ``BluetoothDevice`` device type.
public struct DeviceDiscoveryDescriptor {
    /// The associated device type.
    public let deviceType: any BluetoothDevice.Type
    /// The criteria by which we identify a discovered device.
    public let discoveryCriteria: DiscoveryCriteria

    init<Device: BluetoothDevice>(from discoverExpression: Discover<Device>) {
        self.deviceType = discoverExpression.deviceType
        self.discoveryCriteria = discoverExpression.discoveryCriteria
    }
}


extension DeviceDiscoveryDescriptor: Sendable {}


extension DeviceDiscoveryDescriptor: Identifiable {
    public var id: DiscoveryCriteria {
        discoveryCriteria
    }
}


extension DeviceDiscoveryDescriptor: Hashable {
    public static func == (lhs: DeviceDiscoveryDescriptor, rhs: DeviceDiscoveryDescriptor) -> Bool {
        lhs.discoveryCriteria == rhs.discoveryCriteria
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(discoveryCriteria)
    }
}
