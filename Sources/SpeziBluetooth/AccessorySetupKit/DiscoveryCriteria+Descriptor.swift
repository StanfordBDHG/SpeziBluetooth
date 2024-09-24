//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import AccessorySetupKit


extension DiscoveryCriteria {
    /// Retrieve the `ASDiscoveryDescriptor` representation for the discovery criteria.
    @available(iOS 18.0, *)
    public var discoveryDescriptor: ASDiscoveryDescriptor {
        let descriptor = ASDiscoveryDescriptor()

        // TODO: we cannot support more than one bluetoothServiceUUID

        for aspect in aspects {
            aspect.apply(to: descriptor)
        }

        return descriptor
    }
}
