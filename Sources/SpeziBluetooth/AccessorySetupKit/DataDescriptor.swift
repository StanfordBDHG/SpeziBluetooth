//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

@_spi(TestingSupport)
import ByteCoding
import Foundation


/// A matching descriptor for a `Data`-based field.
///
/// To match against `Data`, you provide the ``data`` you want to match to, with an additional ``mask`` that defines which bits should be considered for the check.
public struct DataDescriptor { // TODO: this could move towards foundation!
    /// The data to match against.
    public let data: Data
    /// The mask that
    public let mask: Data
    
    /// Create a new data descriptor.
    /// - Parameters:
    ///   - data: The data.
    ///   - mask: The mask.
    public init(data: Data, mask: Data) {
        self.data = data
        self.mask = mask
        precondition(mask.count == data.count, "The data mask must the data size. Mask length \(mask.count), data length \(data.count).")
    }
    
    /// Create a new data descriptor with a mask that matches all bits.
    /// - Parameter data: The data.
    public init(data: Data) {
        let mask = Data(repeating: 0xFF, count: data.count)
        self.init(data: data, mask: mask)
    }
    
    /// Determine if the data descriptor matches the provided Data value.
    /// - Parameter value: The data value to check if it matches the descriptor.
    /// - Returns: Return `true` if the bits as defined by ``mask`` if `value` and ``data`` are equal.
    public func matches(_ value: Data) -> Bool {
        guard value.count >= data.count else {
            return false
        }

        let valueMasked = Self.bitwiseAnd(lhs: value, rhs: mask)
        let dataMasked = Self.bitwiseAnd(lhs: data, rhs: mask)

        return valueMasked == dataMasked
    }

    private static func bitwiseAnd(lhs: Data, rhs: Data) -> Data {
        if rhs.count > lhs.count {
            return bitwiseAnd(lhs: rhs, rhs: lhs)
        }

        var value = lhs

        for index in rhs.indices {
            value[index] = lhs[index] & rhs[index]
        }

        return value
    }
}


extension DataDescriptor: Sendable, Hashable {
    public static func == (lhs: DataDescriptor, rhs: DataDescriptor) -> Bool {
        lhs.mask == rhs.mask // TODO: doesn't need to be equal, just describe the same bit pattern (e.g., length doesn't need to match)
        && Self.bitwiseAnd(lhs: lhs.data, rhs: lhs.mask) == Self.bitwiseAnd(lhs: rhs.data, rhs: rhs.mask) // TODO: use the shorter mask?
    }

    // TODO: hashable?
}


extension DataDescriptor: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "DataDescriptor(data: \(data.hexString()), mask: \(mask.hexString()))"
    }

    public var debugDescription: String {
        description
    }
}
