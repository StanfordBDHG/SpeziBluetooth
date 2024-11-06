//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


/// An event handler registration for accessory events.
///
/// It automatically cancels the subscription once this value is de-initialized.
public struct AccessoryEventRegistration: ~Copyable, Sendable {
    private let id: UUID
    private weak var setupKit: (AnyObject & Sendable)? // type erased as AccessorySetupKit is only available on iOS 18 platform.

    @available(iOS 18.0, *)
    @available(macCatalyst, unavailable)
    init(id: UUID, setupKit: AccessorySetupKit?) {
        self.id = id
        self.setupKit = setupKit
    }

    static func cancel(id: UUID, setupKit: (AnyObject & Sendable)?, isolation: isolated (any Actor)? = #isolation) {
#if os(iOS) && !targetEnvironment(macCatalyst)
        guard #available(iOS 18, *) else {
            return
        }

        guard let setupKit, let typedSetupKit = setupKit as? AccessorySetupKit else {
            return
        }

        typedSetupKit.cancelHandler(for: id)
#else
        preconditionFailure("Not available on this platform!")
#endif
    }

    /// Cancel the subscription.
    /// - Parameter isolation: Inherits the current actor isolation. If running on the MainActor cancellation is processed instantly.
    public func cancel(isolation: isolated (any Actor)? = #isolation) {
        Self.cancel(id: id, setupKit: setupKit)
    }

    deinit {
        Self.cancel(id: id, setupKit: setupKit)
    }
}
