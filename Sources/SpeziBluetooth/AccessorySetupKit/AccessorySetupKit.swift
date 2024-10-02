//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import AccessorySetupKit
import Spezi


/// Enable privacy-preserving discovery and configuration of accessories through Apple's AccessorySetupKit.
///
/// This module enables to discover and configure Bluetooth or Wi-Fi accessories using Apple's [AccessorySetupKit](https://developer.apple.com/documentation/accessorysetupkit).
///
/// - Important: Make sure to follow all the setup instructions in [Declare your app's accessories](https://developer.apple.com/documentation/accessorysetupkit/discovering-and-configuring-accessories#Declare-your-apps-accessories)
///     to declare all the necessary accessory information in your `Info.plist` file.
///
/// ## Topics
///
/// ### Configuration
/// - ``init()``
///
/// ### Discovered Accessories
/// - ``accessories``
///
/// ### Observe Accessory Changes
/// - ``AccessoryEvent``
/// - ``AccessoryChangeHandler``
///
/// ### Displaying an accessory picker
/// - ``showPicker(for:)``
/// - ``pickerPresented``
///
/// ### Managing Accessories
/// - ``renameAccessory(_:options:)``
/// - ``removeAccessory(_:)``
///
/// ### Managing Authorization
/// - ``finishAuthorization(for:settings:)``
/// - ``failAuthorization(for:)``
///
/// ### Determine Support
/// - ``supportedProtocols``
/// - ``SupportedProtocol``
@MainActor
@available(iOS 18.0, *)
public final class AccessorySetupKit {
    @MainActor
    @Observable
    fileprivate final class State {
        var pickerPresented = false
        let accessories: Void = ()

        nonisolated init() {}
    }

    @Application(\.logger)
    private var logger

    private let session = ASAccessorySession()
    private let state = State()

    /// Determine if the accessory picker is currently being presented.
    public var pickerPresented: Bool {
        state.pickerPresented
    }

    /// Previously selected accessories for this application.
    public var accessories: [ASAccessory] {
        state.access(keyPath: \.accessories)
        return session.accessories
    }

    private var accessoryChangeHandlers: [UUID: (AccessoryEvent) -> Void] = [:]

    /// Initialize the accessory setup kit.
    public nonisolated init() {}

    /// Configure the Module.
    @_documentation(visibility: internal)
    public func configure() {
        self.session.activate(on: DispatchQueue.main) { [weak self] event in
            guard let self else {
                return
            }
            MainActor.assumeIsolated {
                self.handleSessionEvent(event: event)
            }
        }
    }
    
    /// Register an event handler for `AccessoryEvent`s.
    /// - Parameter eventHandler: The event handler that receives the ``AccessoryEvent``s.
    /// - Returns: Returns a ``EventHandlerRegistration`` that you should keep track of and allows to cancel the event handler.
    public func registerHandler(eventHandler: @escaping (AccessoryEvent) -> Void) -> EventHandlerRegistration {
        let id = UUID()
        accessoryChangeHandlers[id] = eventHandler
        return EventHandlerRegistration(id: id, setupKit: self)
    }

    /// Discover display items in picker.
    /// - Parameter items: The known display items to discover.
    public func showPicker(for items: [ASPickerDisplayItem]) async throws {
        // session is not Sendable (explicitly marked as non-Sendable), therefore we cannot call async functions on that type.
        // Even though they exist, we cannot call them in Swift 6(! ... Apple), and thus we need to manually create a continuation
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.showPicker(for: items) { error in
                if let error {
                    continuation.resume(throwing: AccessorySetupKitError.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    /// Rename accessory.
    ///
    /// Calling this method will show a picker view that allows to rename the accessory.
    /// - Parameters:
    ///   - accessory: The accessory.
    ///   - renameOptions: The rename options.
    public func renameAccessory(_ accessory: ASAccessory, options renameOptions: ASAccessory.RenameOptions = []) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.renameAccessory(accessory, options: renameOptions) { error in
                if let error {
                    continuation.resume(throwing: AccessorySetupKitError.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    /// Remove an accessory from the application.
    ///
    /// If this application is the last one to access the accessory, it will be permanently un-paired from the device.
    /// - Parameter accessory: The accessory to remove or forget.
    public func removeAccessory(_ accessory: ASAccessory) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.removeAccessory(accessory) { error in
                if let error {
                    continuation.resume(throwing: AccessorySetupKitError.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Finish accessory setup awaiting authorization.
    /// - Parameters:
    ///   - accessory: The accessory awaiting authorization.
    ///   - settings: The accessory settings.
    public func finishAuthorization(for accessory: ASAccessory, settings: ASAccessorySettings) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.finishAuthorization(for: accessory, settings: settings) { error in
                if let error {
                    continuation.resume(throwing: AccessorySetupKitError.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    /// Fail accessory setup awaiting authorization.
    /// - Parameter accessory: The accessory awaiting authorization.
    public func failAuthorization(for accessory: ASAccessory) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.failAuthorization(for: accessory) { error in
                if let error {
                    continuation.resume(throwing: AccessorySetupKitError.mapError(error))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func callHandler(with event: AccessoryEvent) {
        for handler in accessoryChangeHandlers.values {
            handler(event)
        }
    }

    private func handleSessionEvent(event: ASAccessoryEvent) { // swiftlint:disable:this cyclomatic_complexity
        if let accessory = event.accessory {
            logger.debug("Dispatching Accessory Session event \(event.eventType) for accessory \(accessory)")
        } else {
            logger.debug("Dispatching Accessory Session event \(event.eventType)")
        }

        switch event.eventType {
        case .activated:
            state.withMutation(keyPath: \.accessories) {}
            callHandler(with: .available)
        case .invalidated:
            break
        case .migrationComplete:
            break
        case .accessoryAdded:
            guard let accessory = event.accessory else {
                return
            }
            state.withMutation(keyPath: \.accessories) {}
            callHandler(with: .added(accessory))
        case .accessoryRemoved:
            guard let accessory = event.accessory else {
                return
            }
            state.withMutation(keyPath: \.accessories) {}
            callHandler(with: .removed(accessory))
        case .accessoryChanged:
            guard let accessory = event.accessory else {
                return
            }
            state.withMutation(keyPath: \.accessories) {}
            callHandler(with: .changed(accessory))
        case .pickerDidPresent:
            state.pickerPresented = true
        case .pickerDidDismiss:
            state.pickerPresented = false
        case .pickerSetupBridging, .pickerSetupFailed, .pickerSetupPairing, .pickerSetupRename:
            break
        case .unknown:
            break
        @unknown default:
            logger.warning("The Accessory Setup session is unknown: \(event.eventType)")
        }
    }
}


@available(iOS 18.0, *)
extension AccessorySetupKit: Module, DefaultInitializable, Sendable {}


@available(iOS 18.0, *)
extension AccessorySetupKit {
    /// Accessory-related events.
    public enum AccessoryEvent {
        /// The ``AccessorySetupKit/accessories`` property is now available.
        case available
        /// New accessory was successfully added.
        case added(ASAccessory)
        /// An accessory was removed.
        case removed(ASAccessory)
        /// An accessory was changed.
        case changed(ASAccessory)
    }
}


@available(iOS 18.0, *)
extension AccessorySetupKit {
    /// An event handler registration for accessory events.
    ///
    /// It automatically cancels the subscription once this value is de-initialized.
    public struct EventHandlerRegistration: ~Copyable {
        private let id: UUID
        private weak var setupKit: AccessorySetupKit?

        fileprivate init(id: UUID, setupKit: AccessorySetupKit?) {
            self.id = id
            self.setupKit = setupKit
        }

        /// Cancel the subscription.
        /// - Parameter isolation: Inherits the current actor isolation.
        public func cancel(isolation: isolated (any Actor)? = #isolation) {
            guard let setupKit else {
                return
            }
            let id = id

            if isolation === MainActor.shared {
                MainActor.assumeIsolated {
                    _ = setupKit.accessoryChangeHandlers.removeValue(forKey: id)
                }
            } else {
                Task { @MainActor in
                    _ = setupKit.accessoryChangeHandlers.removeValue(forKey: id)
                }
            }
        }

        deinit {
            guard let setupKit else {
                return
            }
            let id = id
            Task { @MainActor in
                setupKit.accessoryChangeHandlers.removeValue(forKey: id)
            }
        }
    }
}


@available(iOS 18.0, *)
extension AccessorySetupKit.AccessoryEvent: Sendable, Hashable {}


@available(iOS 18.0, *)
extension AccessorySetupKit.AccessoryEvent: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        switch self {
        case .available:
            "available"
        case let .added(accessory):
            ".added(\(accessory))"
        case let .removed(accessory):
            ".removed(\(accessory))"
        case let .changed(accessory):
            ".changed(\(accessory))"
        }
    }

    public var debugDescription: String {
        description
    }
}


@available(iOS 18.0, *)
extension AccessorySetupKit {
    /// A supported protocol of the accessory setup kit.
    public struct SupportedProtocol {
        /// The raw value identifier.
        public let rawValue: String
        
        /// Initialize a new supported protocol.
        /// - Parameter rawValue: The raw value identifier.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
    
    /// Retrieve the supported protocols that are defined in the `Info.plist` of the `main` bundle.
    public static nonisolated var supportedProtocols: [SupportedProtocol] {
        (Bundle.main.object(forInfoDictionaryKey: "NSAccessorySetupKitSupports") as? [String] ?? []).map { .init(rawValue: $0) }
    }
}


@available(iOS 18.0, *)
extension AccessorySetupKit.SupportedProtocol: Hashable, Sendable, RawRepresentable {}

@available(iOS 18.0, *)
extension AccessorySetupKit.SupportedProtocol {
    /// Discover accessories using Bluetooth or Bluetooth Low Energy.
    public static let bluetooth = AccessorySetupKit.SupportedProtocol(rawValue: "Bluetooth")
    /// Discover accessories using wifi SSIDs.
    public static let wifi = AccessorySetupKit.SupportedProtocol(rawValue: "WiFi")
}
