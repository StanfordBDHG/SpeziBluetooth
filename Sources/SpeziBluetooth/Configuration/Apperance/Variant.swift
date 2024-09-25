//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziViews


/// Describes the appearance of a device variant and criteria that identify the variant.
public struct Variant {
    /// A unique and persistent identifier for the device variant.
    ///
    /// As the ``criteria`` can only be used upon discovery to identify a device variant, the `id` can be used in persistent storage to
    /// identify the variant of a device. Make sure this identifier doesn't change and is unique for the device.
    public let id: String
    /// Provides a user-friendly name for the device.
    ///
    /// This might be treated as the "initial" name. A user might be allowed to rename the device locally.
    public let name: String
    /// An icon that is used to refer to the device.
    public let icon: ImageReference
    /// The criteria that identify a device variant and distinguish the variant from other device variants.
    public let criteria: DeviceVariantCriteria
    
    /// Create a new device variant.
    /// - Parameters:
    ///   - id: A unique and persistent identifier for the device variant.
    ///   - name: A user-friendly name for the device.
    ///   - icon: An icon that is used to refer to the device.
    ///   - criteria: The criteria that identify a device variant and distinguish the variant from other device variants.
    /// - Precondition: You have to provide at least one device variant criteria: `!criteria.isEmpty`
    public init(id: String, name: String, icon: ImageReference = .system("sensor"), criteria: DeviceVariantCriteria...) {
        // swiftlint:disable:previous function_default_parameter_at_end
        precondition(!criteria.isEmpty, "At least one device variant criteria must be provided")

        self.id = id
        self.name = name
        self.icon = icon
        self.criteria = DeviceVariantCriteria(from: criteria)
    }
}


extension Variant: Hashable, Sendable, Identifiable {}
