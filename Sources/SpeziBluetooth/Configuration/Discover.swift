//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// Declare how a bluetooth device is discovered.
///
/// Declares by which ``DiscoveryCriteria`` a given ``BluetoothDevice`` implementation is discovered.
///
/// - Important: The discovery criteria must be unique across all discovery configurations. Not doing so will result in undefined behavior.
///
/// ```swift
/// Discover(MyBluetoothDevice.self, by: .advertisedService(WeightScaleService.self))
/// ```
///
/// ### Describing Device Appearance
///
/// You can use the `appearance` parameter of the initializer to customize the ``Appearance`` of your device and how UI components might present
/// the device to the user.
///
/// Your device might implement the logic for multiple device variants that might look different. Use the result builder closure to specify your device ``Variant``s.
///
/// ```swift
/// Discover(MyBluetoothDevice.self, by: .advertisedService(WeightScaleService.self)) {
///     Variant(id: "model-p1", name: "Weight Scale", icon: .asset("Model-P1"), criteria: .nameSubstring("WS-P1"))
///     Variant(id: "model-x2", name: "Weight Scale", icon: .asset("Model-X2"), criteria: .nameSubstring("WS-X2"))
/// }
/// ```
///
/// ## Topics
///
/// ### Discovering a device
///
/// - ``init(_:by:appearance:)``
/// - ``init(_:by:appearance:variants:)``
///
/// ### Semantic Model
/// - ``DeviceDiscoveryDescriptor``
/// - ``DiscoveryDescriptorBuilder``
public struct Discover<Device: BluetoothDevice> {
    let deviceType: Device.Type
    let discoveryCriteria: DiscoveryCriteria

    let appearance: DeviceAppearance

    /// Create a discovery for a given device type.
    /// - Parameters:
    ///   - device: The type of a ``BluetoothDevice`` implementation.
    ///   - discoveryCriteria: The criteria by which the device is discovered.
    ///   - appearance: Describes how the device should be visually presented in UI components.
    public init(_ device: Device.Type, by discoveryCriteria: DiscoveryCriteria, appearance: Appearance = Appearance(name: "\(Device.self)")) {
        self.deviceType = device
        self.discoveryCriteria = discoveryCriteria
        self.appearance = .appearance(appearance)
    }
    
    /// Create a discovery for a given device type.
    ///
    /// This initializer allows to provide additional information about device variants. A single ``BluetoothDevice`` implementation might be used with multiple variants
    /// of a given device class (e.g., multiple models of a blood pressure cuff). You can provide additional device ``Variant``s to describe the visual appearance of the different
    /// device variants.
    /// - Parameters:
    ///   - device: The type of a ``BluetoothDevice`` implementation.
    ///   - discoveryCriteria: The criteria by which the device is discovered.
    ///   - appearance: Describes how the generic device class should be presented in UI components. This appearance is used if there isn't a matching device variant found.
    ///   - variants: Provide the device ``Variant`` as a closure.
    public init(
        _ device: Device.Type,
        by discoveryCriteria: DiscoveryCriteria,
        appearance: Appearance = Appearance(name: "\(Device.self)"),
        @DeviceVariantBuilder variants: () -> [Variant]
    ) {
        self.deviceType = device
        self.discoveryCriteria = discoveryCriteria

        let variants = variants()
        if variants.isEmpty {
            self.appearance = .appearance(appearance)
        } else {
            self.appearance = .variants(defaultAppearance: appearance, variants: variants)
            // TODO: check uniqueness of the device variants?
        }
    }
}


extension Discover: Sendable {}
