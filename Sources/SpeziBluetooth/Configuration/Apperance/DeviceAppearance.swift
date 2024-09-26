//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziViews


/// Describes the appearances and variants of a device.
public enum DeviceAppearance {
    /// The appearance for the device.
    case appearance(Appearance)
    /// The device represents multiple different device variants that have different appearances.
    ///
    /// The `variants` describe how to identify each variant and its appearance.
    /// The `defaultAppearance` appearance is used if the the variant cannot be determined.
    case variants(defaultAppearance: Appearance, variants: [Variant])
}


extension DeviceAppearance: Hashable, Sendable {}


extension DeviceAppearance {
    /// Retrieve the appearance for a device.
    /// - Parameter variantPredicate: If the device has different variants, this predicate will be used to match the desired variant.
    /// - Returns: Returns the device `appearance` and optionally the `variantId`, if the appearance of a variant was returned.
    public func appearance(where variantPredicate: (Variant) -> Bool) -> (appearance: Appearance, variantId: String?) {
        switch self {
        case let .appearance(appearance):
            (appearance, nil)
        case let .variants(defaultAppearance, variants):
            if let variant = variants.first(where: variantPredicate) {
                (Appearance(name: variant.name, icon: variant.icon), variant.id)
            } else {
                (defaultAppearance, nil)
            }
        }
    }
    
    /// Retrieve the icon appearance of a device.
    /// - Parameter variantId: The optional variant id to query. This id will be used to selected the device variant, if the device declares different variant appearances.
    /// - Returns: Returns the device icon.
    public func deviceIcon(variantId: String?) -> ImageReference {
        appearance { variant in
            variant.id == variantId
        }.appearance.icon
    }

    /// Retrieve the name of a device.
    /// - Parameter variantId: The optional variant id to query. This id will be used to selected the device variant, if the device declares different variant appearances.
    /// - Returns: Returns the device name.
    public func deviceName(variantId: String?) -> String {
        appearance { variant in
            variant.id == variantId
        }.appearance.name
    }
}
