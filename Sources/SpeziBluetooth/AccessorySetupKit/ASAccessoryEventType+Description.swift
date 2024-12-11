//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

#if canImport(AccessorySetupKit) && !os(macOS)
import AccessorySetupKit


extension ASAccessoryEventType: @retroactive CustomStringConvertible, @retroactive CustomDebugStringConvertible {
    public var description: String {
        switch self {
        case .unknown:
            "unknown"
        case .activated:
            "activated"
        case .invalidated:
            "invalidated"
        case .migrationComplete:
            "migrationComplete"
        case .accessoryAdded:
            "accessoryAdded"
        case .accessoryRemoved:
            "accessoryRemoved"
        case .accessoryChanged:
            "accessoryChanged"
        case .pickerDidPresent:
            "pickerDidPresent"
        case .pickerDidDismiss:
            "pickerDidDismiss"
        case .pickerSetupBridging:
            "pickerSetupBridging"
        case .pickerSetupFailed:
            "pickerSetupFailed"
        case .pickerSetupPairing:
            "pickerSetupPairing"
        case .pickerSetupRename:
            "pickerSetupRename"
        @unknown default:
            "ASAccessoryEventType(rawValue: \(rawValue))"
        }
    }

    public var debugDescription: String {
        description
    }
}
#endif
