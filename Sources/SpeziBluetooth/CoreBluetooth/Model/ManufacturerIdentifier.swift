//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import NIOCore


/// Bluetooth SIG-assigned Manufacturer Identifier.
///
/// Refer to Assigned Numbers 7. Company Identifiers.
public struct ManufacturerIdentifier {
    /// The raw manufacturer identifier.
    public let rawValue: UInt16

    /// Initialize a new manufacturer identifier form its code.
    /// - Parameter code: The Bluetooth SIG-assigned Manufacturer Identifier.
    public init(_ code: UInt16) {
        self.init(rawValue: code)
    }
}


extension ManufacturerIdentifier: Hashable, Sendable {}


extension ManufacturerIdentifier: RawRepresentable {
    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
}


extension ManufacturerIdentifier: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt16) {
        self.init(rawValue: value)
    }
}


extension ManufacturerIdentifier: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer) {
        guard let rawValue = UInt16(from: &byteBuffer) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public func encode(to byteBuffer: inout ByteBuffer) {
        rawValue.encode(to: &byteBuffer)
    }
}
