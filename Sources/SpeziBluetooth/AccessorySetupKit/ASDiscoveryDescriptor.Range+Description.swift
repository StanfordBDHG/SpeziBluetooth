//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import AccessorySetupKit


@available(iOS 18, *)
extension ASDiscoveryDescriptor.Range: @retroactive CustomStringConvertible, @retroactive CustomDebugStringConvertible {
    public var description: String {
        switch self {
        case .default:
            "default"
        case .immediate:
            "immediate"
        @unknown default:
            "Range(rawValue: \(rawValue))"
        }
    }

    public var debugDescription: String {
        description
    }
}
