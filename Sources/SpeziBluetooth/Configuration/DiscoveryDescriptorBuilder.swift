//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Building a set of `Discover` expressions to express what peripherals to discover.
@resultBuilder
public enum DiscoveryDescriptorBuilder {
    /// Build a ``Discover`` expression to define a ``DeviceDiscoveryDescriptor``.
    public static func buildExpression<Device: BluetoothDevice>(_ expression: Discover<Device>) -> Set<DeviceDiscoveryDescriptor> {
        [DeviceDiscoveryDescriptor(from: expression)]
    }

    /// Build a block of ``DeviceDiscoveryDescriptor``s.
    public static func buildBlock(_ components: Set<DeviceDiscoveryDescriptor>...) -> Set<DeviceDiscoveryDescriptor> {
        buildArray(components)
    }

    /// Build the first block of an conditional ``DeviceDiscoveryDescriptor`` component.
    public static func buildEither(first component: Set<DeviceDiscoveryDescriptor>) -> Set<DeviceDiscoveryDescriptor> {
        component
    }

    /// Build the second block of an conditional ``DeviceDiscoveryDescriptor`` component.
    public static func buildEither(second component: Set<DeviceDiscoveryDescriptor>) -> Set<DeviceDiscoveryDescriptor> {
        component
    }

    /// Build an optional ``DeviceDiscoveryDescriptor`` component.
    public static func buildOptional(_ component: Set<DeviceDiscoveryDescriptor>?) -> Set<DeviceDiscoveryDescriptor> {
        // swiftlint:disable:previous discouraged_optional_collection
        component ?? []
    }

    /// Build an ``DeviceDiscoveryDescriptor`` component with limited availability.
    public static func buildLimitedAvailability(_ component: Set<DeviceDiscoveryDescriptor>) -> Set<DeviceDiscoveryDescriptor> {
        component
    }

    /// Build an array of ``DeviceDiscoveryDescriptor`` components.
    public static func buildArray(_ components: [Set<DeviceDiscoveryDescriptor>]) -> Set<DeviceDiscoveryDescriptor> {
        components.reduce(into: []) { result, component in
            result.formUnion(component)
        }
    }
}
