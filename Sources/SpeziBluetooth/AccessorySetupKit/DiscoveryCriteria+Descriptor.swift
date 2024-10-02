//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

#if canImport(AccessorySetupKit) && !os(macOS)
import AccessorySetupKit


@available(iOS 18.0, *)
@available(macCatalyst, unavailable)
extension DiscoveryCriteria {
    /// Retrieve the `ASDiscoveryDescriptor` representation for the discovery criteria.
    public var discoveryDescriptor: ASDiscoveryDescriptor {
        let descriptor = ASDiscoveryDescriptor()

        if aspects.count(where: { $0.isServiceId }) > 1 {
            Bluetooth.logger.warning(
                """
                DiscoveryCriteria has multiple service uuids specified. This is not supported by AccessorySetupKit and only the first one \
                will be used with the ASDiscoveryDescriptor: \(self).
                """
            )
        }

        for aspect in aspects {
            aspect.apply(to: descriptor)
        }

        return descriptor
    }
    
    /// Determine if a discovery descriptor matches the discovery criteria.
    /// - Parameter descriptor: The discovery descriptor.
    /// - Returns: Returns `true` if all discovery aspects are present and matching on the discovery descriptor. The discovery descriptor might have other fields set.
    public func matches(descriptor: ASDiscoveryDescriptor) -> Bool {
        aspects.allSatisfy { aspect in
            aspect.matches(descriptor)
        }
    }
}
#endif
