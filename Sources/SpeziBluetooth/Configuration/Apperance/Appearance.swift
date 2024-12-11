//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziViews


/// Describes how a bluetooth device should be visually presented to the user.
public struct Appearance {
    /// Provides a user-friendly name for the device.
    ///
    /// This might be treated as the "initial" name. A user might be allowed to rename the device locally.
    public let name: String
    /// An icon that is used to refer to the device.
    public let icon: ImageReference
    
    /// Create a new device appearance.
    /// - Parameters:
    ///   - name: Provides a user-friendly name for the device.
    ///   - icon: An icon that is used to refer to the device.
    public init(name: String, icon: ImageReference = .system("sensor")) {
        self.name = name
        self.icon = icon
    }
}


extension Appearance: Hashable, Sendable {}
