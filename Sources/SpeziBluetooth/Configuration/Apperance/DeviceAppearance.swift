//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziViews


/// Describes the appearances of a device.
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
