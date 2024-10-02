//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

#if canImport(AccessorySetupKit) && !os(macOS)
import AccessorySetupKit


@available(iOS 18, *)
@available(macCatalyst, unavailable)
extension DeviceVariantCriteria {
    /// Apply criteria to a `ASDiscoveryDescriptor`.
    /// - Parameter descriptor: The descriptor.
    public func apply(to descriptor: ASDiscoveryDescriptor) {
        for aspect in aspects {
            aspect.apply(to: descriptor)
        }
    }

    /// Determine if a discovery descriptor matches the device variant criteria.
    /// - Parameter descriptor: The discovery descriptor.
    /// - Returns: Returns `true` if all discovery aspects are present and matching on the discovery descriptor. The discovery descriptor might have other fields set.
    public func matches(descriptor: ASDiscoveryDescriptor) -> Bool {
        aspects.allSatisfy { aspect in
            aspect.matches(descriptor)
        }
    }
}
#endif
