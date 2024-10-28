//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


private struct ConnectedDeviceEnvironmentModifier<Device: BluetoothDevice>: ViewModifier {
    @Environment(ConnectedDevicesModel.self)
    var connectedDevices

    @State private var devicesList = ConnectedDevices<Device>()

    init() {}


    func body(content: Content) -> some View {
        let connectedDeviceAny = connectedDevices[ObjectIdentifier(Device.self)]
        let firstConnectedDevice = connectedDeviceAny.first as? Device
        let connectedDevicesList = connectedDeviceAny.compactMap { device in
            device as? Device
        }

        let _ = devicesList.devices = connectedDevicesList // swiftlint:disable:this redundant_discardable_let

        content
            .environment(firstConnectedDevice)
            .environment(devicesList)
    }
}


struct ConnectedDevicesEnvironmentModifier: ViewModifier {
    private let configuredDeviceTypes: [any BluetoothDevice.Type]

    @Environment(ConnectedDevicesModel.self)
    var connectedDevices


    init(configuredDeviceTypes: [any BluetoothDevice.Type]) {
        self.configuredDeviceTypes = configuredDeviceTypes
    }


    func body(content: Content) -> some View {
        let modifiers = configuredDeviceTypes.map { $0.deviceEnvironmentModifier }

        modifiers.modify(content)
    }
}


extension BluetoothDevice {
    @MainActor fileprivate static var deviceEnvironmentModifier: any ViewModifier {
        ConnectedDeviceEnvironmentModifier<Self>()
    }
}


extension Array where Element == any ViewModifier {
    @MainActor
    fileprivate func modify<V: View>(_ view: V) -> AnyView {
        var view = AnyView(view)
        for modifier in self {
            view = modifier.modify(view)
        }
        return view
    }
}


extension ViewModifier {
    fileprivate func modify(_ view: AnyView) -> AnyView {
        AnyView(view.modifier(self))
    }
}
