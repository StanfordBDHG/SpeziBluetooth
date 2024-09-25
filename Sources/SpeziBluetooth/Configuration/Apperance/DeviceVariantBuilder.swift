//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//


import SpeziViews

/// Building a set of device `Variant`s to express the different appearances of a device.
@resultBuilder
public enum DeviceVariantBuilder {
    /// Builder a ``Variant`` expression.
    public static func buildExpression(_ expression: Variant) -> [Variant] {
        [expression]
    }
    
    /// Builder a block of ``Variant``s.
    public static func buildBlock(_ components: [Variant]...) -> [Variant] {
        components.flatMap { $0 }
    }

    /// Build the first block of an conditional ``Variant`` component.
    public static func buildEither(first component: [Variant]) -> [Variant] {
        component
    }

    /// Build the second block of an conditional ``Variant`` component.
    public static func buildEither(second component: [Variant]) -> [Variant] {
        component
    }

    /// Build an ``Variant`` component with limited availability.
    public static func buildLimitedAvailability(_ component: [Variant]) -> [Variant] {
        component
    }

    /// Build an array of ``Variant`` components.
    public static func buildArray(_ components: [[Variant]]) -> [Variant] {
        components.flatMap { $0 }
    }
}
