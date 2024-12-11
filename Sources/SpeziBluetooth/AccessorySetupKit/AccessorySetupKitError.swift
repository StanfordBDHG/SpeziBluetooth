//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

#if canImport(AccessorySetupKit) && !os(macOS)
import AccessorySetupKit
#endif
import Foundation


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


#if canImport(AccessorySetupKit) && !os(macOS)
@available(iOS 18, *)
@available(macCatalyst, unavailable)
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
#endif

extension AccessorySetupKitError: LocalizedError {
    public var errorDescription: String? {
        String(localized: errorDescriptionLocalization, bundle: .module)
    }

    public var failureReason: String? {
        String(localized: failureReasonLocalization, bundle: .module)
    }

    private var errorDescriptionLocalization: String.LocalizationValue {
        switch self {
        case .success:
            "Success"
        case .unknown:
            "Unknown"
        case .activationFailed:
            "Activation Failed"
        case .connectionFailed:
            "Connection Failed"
        case .discoveryTimeout:
            "Discovery Timeout"
        case .extensionNotFound:
            "Extension Not Found"
        case .invalidated:
            "Invalidated"
        case .invalidRequest:
            "Invalid Request"
        case .pickerAlreadyActive:
            "Busy"
        case .pickerRestricted:
            "Restricted"
        case .userCancelled:
            "Cancelled"
        case .userRestricted:
            "Restricted"
        }
    }

    private var failureReasonLocalization: String.LocalizationValue {
        switch self {
        case .success:
            "Operation completed successfully."
        case .unknown:
            "Unknown error occurred."
        case .activationFailed:
            "Unable to activate discovery session."
        case .connectionFailed:
            "Unable to establish connection with the accessory."
        case .discoveryTimeout:
            "Discovery session timed out."
        case .extensionNotFound:
            "Unable to locate the App Extension."
        case .invalidated:
            "Invalidate was called before the operation completed normally."
        case .invalidRequest:
            "Received an invalid request."
        case .pickerAlreadyActive:
            "The picker is already active."
        case .pickerRestricted:
            "The picker is restricted due to the application being in the background."
        case .userCancelled:
            "The user cancelled the discovery."
        case .userRestricted:
            "Access was restricted by the user."
        }
    }
}
