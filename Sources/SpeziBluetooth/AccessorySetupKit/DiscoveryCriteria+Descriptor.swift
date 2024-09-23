//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

// TODO: declare support in the Info.plist!


import AccessorySetupKit
import Spezi

// TODO: support for migration within SpeziDevices!

// TODO: make this part of a SpeziBluetoothAccessorySetupKitSupport?

// TODO: support name, manufacturer data, service data etc!


extension ManufacturerIdentifier {
    @available(iOS 18.0, *)
    public var bluetoothCompanyIdentifier: ASBluetoothCompanyIdentifier {
        ASBluetoothCompanyIdentifier(rawValue)
    }
}


extension DiscoveryCriteria {
    @available(iOS 18.0, *)
    public var discoveryDescriptor: ASDiscoveryDescriptor {
        let descriptor = ASDiscoveryDescriptor()

        switch self {
        case let .advertisedServices(uuids):
            descriptor.bluetoothServiceUUID = uuids.first?.cbuuid // TODO: we cannot support more than one!
        case let .accessory(manufacturer, services):
            descriptor.bluetoothCompanyIdentifier = manufacturer.bluetoothCompanyIdentifier
            descriptor.bluetoothServiceUUID = services.first?.cbuuid
        }

        // TODO: more extensive setups! service data blob + manufacturer data blob!

        return descriptor
    }
}

// TODO: ASPickerDisplayItem is part of SpeziDevices?
