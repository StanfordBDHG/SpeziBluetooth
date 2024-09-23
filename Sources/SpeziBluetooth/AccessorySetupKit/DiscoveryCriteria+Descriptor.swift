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

@available(iOS 18.0, *)
@MainActor
final class AccessorySetupSession: Module {
    private let session = ASAccessorySession()

    nonisolated init() {}

    func configure() {
        session.activate(on: .main) { [weak self] event in
            guard let self else {
                return
            }
            print("Handling event \(event)")
        }
    }
}


extension ManufacturerIdentifier {
    @available(iOS 18.0, *)
    var bluetoothCompanyIdentifier: ASBluetoothCompanyIdentifier {
        ASBluetoothCompanyIdentifier(rawValue)
    }
}


extension DiscoveryCriteria {
    @available(iOS 18.0, *)
    var discoveryDescriptor: ASDiscoveryDescriptor {
        var descriptor = ASDiscoveryDescriptor()

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
