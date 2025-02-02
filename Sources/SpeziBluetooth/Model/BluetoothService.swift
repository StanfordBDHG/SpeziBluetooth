//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


/// A Bluetooth service implementation.
///
/// This protocol allows you to decoratively define a service of a given Bluetooth peripheral.
/// Use the ``Characteristic`` property wrapper to declare all characteristics of your service.
///
/// - Tip: You may also use the ``DeviceState`` and ``DeviceAction`` property wrappers within your service implementation
///     to interact with the Bluetooth device the service is used on.
///
/// Below is a short code example that implements some parts of the Device Information service.
///
/// ```swift
/// struct DeviceInformationService: BluetoothService {
///    static let id: BTUUID = "180A"
///
///     @Characteristic(id: "2A29")
///     var manufacturer: String?
///     @Characteristic(id: "2A26")
///     var firmwareRevision: String?
/// }
/// ```
///
/// ## Topics
///
/// ### Bluetooth UUID
/// - ``id``
///
/// ### Configuration
/// - ``configure()``
public protocol BluetoothService {
    /// The Bluetooth service id.
    static var id: BTUUID { get }
    
    /// Configure the bluetooth service.
    ///
    /// Use this method to perform initial configuration of the service (e.g., set up `onChange` handlers).
    /// This method is called by the ``Bluetooth`` module, once the device is getting configured.
    @SpeziBluetooth
    func configure()
}


extension BluetoothService {
    /// Empty default configure method.
    public func configure() {}
}
