//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Observation
import Spezi


/// A Bluetooth device implementation.
///
/// This protocol allows you to decoratively define your Bluetooth peripheral.
/// Use the ``Service`` property wrapper to declare all services of your device.
///
/// - Tip: You can use the ``DeviceState`` and ``DeviceAction`` property wrappers to retrieve device state
///     or interact with your Bluetooth device.
///
/// Below is a short code example of a device that implements a Device Information and Heart Rate service.
///
/// ```swift
/// class MyDevice: BluetoothDevice {
///     @Service var deviceInformation = DeviceInformationService()
///     @Service var heartRate = HeartRateService()
///
///     init() {}
/// }
/// ```
///
/// ### Describing Device Appearance
///
/// You can use the ``appearance`` property to customize the ``Appearance`` of your device and how UI components might present
/// the device to the user.
///
/// Your device might implement the logic for multiple device variants that might have a different appearance. Provide a ``DeviceAppearance`` to describe the appearance of your device
///
/// ```swift
/// final class MyBluetoothDevice: BluetoothDevice {
///     static let appearance: DeviceAppearance = .variants(defaultAppearance: Appearance(name: "Weight Scale"), variants: [
///         Variant(id: "model-p1", name: "Weight Scale P1", icon: .asset("Model-P1"), criteria: .nameSubstring("WS-P1")),
///         Variant(id: "model-x2", name: "Weight Scale X2", icon: .asset("Model-X2"), criteria: .nameSubstring("WS-X2"))
///     ])
///
///     init() {}
/// }
/// ```
///
/// ## Topics
/// ### Initializer
/// - ``init()``
///
/// ### Appearance
/// - ``appearance``
/// - ``DeviceAppearance``
/// - ``Appearance``
/// - ``Variant``
/// - ``DeviceVariantCriteria``
public protocol BluetoothDevice: AnyObject, Module, Observable, Sendable {
    /// Describes the visual appearance of the device.
    ///
    /// The device appearance can be used to visually present the device to the user.
    ///
    /// A device implementation might be used with multiple variants of a given device class (e.g., multiple models of a blood pressure cuff).
    /// You can provide additional variants using ``DeviceAppearance/variants(defaultAppearance:variants:)`` to describe the visual appearance of the different device variants.
    static var appearance: DeviceAppearance { get }

    /// Initializes the Bluetooth Device.
    ///
    /// This initializer is called automatically when a peripheral of this type connects.
    ///
    /// The initializer is called on the Bluetooth Task.
    ///
    /// - Note: This initializer is also called upon configuration to inspect the device structure.
    ///     You might want to make sure to not perform any heavy processing within the initializer.
    init()
}


extension BluetoothDevice {
    /// Default device appearance that uses the type name as the name.
    public static var appearance: DeviceAppearance {
        .appearance(Appearance(name: "\(Self.self)"))
    }
}
