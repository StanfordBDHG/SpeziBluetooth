//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import SpeziViews


@resultBuilder
public enum DeviceApperanceBuilder {
    public static func buildExpression(_ expression: DeviceAppearance) -> DeviceAppearance {
        expression
    }

    public static func buildBlock(_ block: DeviceAppearance) -> DeviceAppearance {
        block
    }

    // TODO: not really future proof!
    @available(*, unavailable, message: "A device can only have a single appearance") // TODO: hint to declare variants!
    public static func buildBlock(_ components: DeviceAppearance...) -> DeviceAppearance {
        preconditionFailure("Cannot provide multiple appearances to a device.")
    }
}


public protocol DeviceOption {}



public struct DeviceAppearance: DeviceOption { // TODO: just call it Appearance?
    public let name: String
    public let icon: ImageReference? // TODO: should be provide the sensor icon by default or let people choose their own?

    public init(name: String, icon: ImageReference? = nil) {
        self.name = name
        self.icon = icon
    }
}
