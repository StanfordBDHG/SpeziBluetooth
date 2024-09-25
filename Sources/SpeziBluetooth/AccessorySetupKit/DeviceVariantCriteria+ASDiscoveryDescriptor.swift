//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import AccessorySetupKit


@available(iOS 18, *)
extension DeviceVariantCriteria {
    /// Apply criteria to a `ASDiscoveryDescriptor`.
    /// - Parameter descriptor: The descriptor.
    public func apply(to descriptor: ASDiscoveryDescriptor) {
        for aspect in aspects {
            aspect.apply(to: descriptor)
        }
    }
}
