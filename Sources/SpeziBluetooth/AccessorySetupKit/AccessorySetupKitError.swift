//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import AccessorySetupKit


/// The `ASError` from `AccessorySetupKit` mapped to Swift.
///
/// ## Topics
/// ### Activation Errors
/// - ``activationFailed``
///
/// ### Lifecycle Errors
/// - ``invalidated``
///
/// ### Configuration Errors
/// - ``extensionNotFound``
/// - ``invalidRequest``
///
/// ### Picker Errors
/// - ``pickerRestricted``
/// - ``pickerAlreadyActive``
///
/// ### Cancellation and Permission Errors
/// - ``userCancelled``
/// - ``userRestricted``
///
/// ### Communication Errors
/// - ``connectionFailed``
/// - ``discoveryTimeout``
///
/// ### Success Case
/// - ``success``
///
/// ### Unknown Error
/// - ``unknown``
public enum AccessorySetupKitError {
    /// Success
    case success
    /// Unknown
    case unknown
    /// Unable to activate discovery session.
    case activationFailed
    /// Unable to establish connection with accessory.
    case connectionFailed
    /// Discovery timed out.
    case discoveryTimeout
    /// Unable to find App Extension.
    case extensionNotFound
    /// Invalidate was called before the operation completed normally.
    case invalidated
    /// Invalid request.
    case invalidRequest
    /// Picker already active.
    case pickerAlreadyActive
    /// Picker restricted due to the application being in background.
    case pickerRestricted
    /// User cancelled.
    case userCancelled
    /// Access restricted by user.
    case userRestricted
}


extension AccessorySetupKitError: Error {}


@available(iOS 18, *)
extension AccessorySetupKitError {
    /// Create a new error from an `ASError`.
    /// - Parameter error: The `ASError`.
    public init(from error: ASError) { // swiftlint:disable:this cyclomatic_complexity
        switch error.code {
        case .success:
            self = .success
        case .unknown:
            self = .unknown
        case .activationFailed:
            self = .activationFailed
        case .connectionFailed:
            self = .connectionFailed
        case .discoveryTimeout:
            self = .discoveryTimeout
        case .extensionNotFound:
            self = .extensionNotFound
        case .invalidated:
            self = .invalidated
        case .invalidRequest:
            self = .invalidRequest
        case .pickerAlreadyActive:
            self = .pickerAlreadyActive
        case .pickerRestricted:
            self = .pickerRestricted
        case .userCancelled:
            self = .userCancelled
        case .userRestricted:
            self = .userRestricted
        @unknown default:
            Bluetooth.logger.warning("Detected unknown ASError code: \(error.code.rawValue)")
            self = .unknown
        }
    }


    static func mapError(_ error: Error) -> Error {
        if let asError = error as? ASError {
            AccessorySetupKitError(from: asError)
        } else {
            error
        }
    }
}
