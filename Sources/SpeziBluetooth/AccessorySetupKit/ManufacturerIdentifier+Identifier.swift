//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

#if canImport(AccessorySetupKit) && !os(macOS)
import AccessorySetupKit


extension ManufacturerIdentifier {
    /// Retrieve the `ASBluetoothCompanyIdentifier` representation for the manufacturer identifier.
    @available(iOS 18.0, *)
    public var bluetoothCompanyIdentifier: ASBluetoothCompanyIdentifier {
        ASBluetoothCompanyIdentifier(rawValue)
    }
}
#endif
