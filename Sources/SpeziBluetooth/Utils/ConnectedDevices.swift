//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


/// Collection of connected devices.
///
/// Use this type to retrieve the list of connected devices from the environment for configured ``BluetoothDevice``s.
///
/// Below is a code example that list all connected devices of the type `MyDevice`.
/// ```swift
/// struct MyView: View {
///     @Environment(ConnectedDevices<MyDevice>.self)
///     var connectedDevices
///
///     var body: some View {
///         List {
///             Section("Connected Devices") {
///                 ForEach(connectedDevices) { device in
///                     Text("\(device.name ?? "unknown")")
///                 }
///             }
///         }
///     }
/// }
/// ```
@Observable
public final class ConnectedDevices<Device: BluetoothDevice> {
    var devices: [Device]

    @MainActor
    init(_ devices: [Device] = []) {
        self.devices = devices
    }
}


extension ConnectedDevices: RandomAccessCollection {
    public var startIndex: Int {
        devices.startIndex
    }

    public var endIndex: Int {
        devices.endIndex
    }

    public func index(after index: Int) -> Int {
        devices.index(after: index)
    }

    public subscript(position: Int) -> Device {
        devices[position]
    }
}
