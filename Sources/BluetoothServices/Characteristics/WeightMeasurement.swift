//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import Foundation
import NIOCore


/// A weight measurement.
///
/// Refer to GATT Specification Supplement, 3.252 Weight Measurement.
public struct WeightMeasurement {
    fileprivate struct Flags: OptionSet {
        let rawValue: UInt8

        static let isImperialUnit = Flags(rawValue: 1 << 0)
        static let timeStampPresent = Flags(rawValue: 1 << 1)
        static let userIdPresent = Flags(rawValue: 1 << 2)
        static let bmiAndHeightPresent = Flags(rawValue: 1 << 3)

        init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }

    /// Units for a weight measurement.
    public enum Unit {
        /// SI units (Weight and Mass in units of kilogram (kg) and Height in units of meter).
        case si
        /// Imperial units. (Weight and Mass in units of pound (lb) and Height in units of inch (in)).
        case imperial
    }

    /// Additional metadata information for a weight measurement.
    public struct AdditionalInfo {
        /// The BMI in units of 0.1 kg/m2.
        public let bmi: UInt16
        /// The height.
        ///
        /// The unit of this value is defined by the ``WeightMeasurement/unit-swift.property`` property.
        /// The value has a resolution of `0.001` in meters and a resolution of `0.1` in inches.
        public let height: UInt16 // TODO: automatic float conversion?


        // TODO: app code docs!
        public init(bmi: UInt16, height: UInt16) {
            self.bmi = bmi
            self.height = height
        }
    }

    /// The weight measurement.
    ///
    /// The unit of this value is defined by the ``unit-swift.property`` property.
    /// The value has a resolution of `0.005` in kg and a resolution of `0.01` in pounds.
    public let weight: UInt16 // TODO: automatic float conversion?
    /// The unit of a weight measurement.
    public let unit: Unit

    /// The timestamp of the measurement.
    public let timeStamp: DateTime?
    /// The associated user of the weight measurement.
    ///
    /// This value can be used to differentiate users if the device supports multiple users.
    /// - Note: The special value of `0xFF` (`UInt8.max`) is used to represent an unknown user.
    ///
    /// The values are left to the implementation but should be unique per device.
    public let userId: UInt8?


    /// Additional information like BMI and Height.
    public let additionalInfo: AdditionalInfo?


    // TODO: app code docs
    public init(weight: UInt16, unit: Unit, timeStamp: DateTime? = nil, userId: UInt8? = nil, additionalInfo: AdditionalInfo? = nil) {
        self.weight = weight
        self.unit = unit
        self.timeStamp = timeStamp
        self.userId = userId
        self.additionalInfo = additionalInfo
    }
}


extension WeightMeasurement {
    public func weight(of resolution: WeightScaleFeature.WeightResolution) -> Double {
        Double(weight) * resolution.magnitude(in: unit)
    }


    public func height(of resolution: WeightScaleFeature.HeightResolution) -> Double? {
        (additionalInfo?.height)
            .map(Double.init)
            .map { $0 * resolution.magnitude(in: unit) }
    }
}


extension WeightMeasurement.Unit: Hashable, Sendable {}


extension WeightMeasurement.AdditionalInfo: Hashable, Sendable {}


extension WeightMeasurement: Hashable, Sendable {}


extension WeightMeasurement.Flags: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let rawValue = UInt8(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        rawValue.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}


extension WeightMeasurement.AdditionalInfo: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let bmi = UInt16(from: &byteBuffer, preferredEndianness: endianness),
              let height = UInt16(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }
        self.init(bmi: bmi, height: height)
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        bmi.encode(to: &byteBuffer, preferredEndianness: endianness)
        height.encode(to: &byteBuffer, preferredEndianness: endianness)
    }
}


extension WeightMeasurement: ByteCodable {
    public init?(from byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        guard let flags = Flags(from: &byteBuffer, preferredEndianness: endianness),
              let weight = UInt16(from: &byteBuffer, preferredEndianness: endianness) else {
            return nil
        }

        self.weight = weight

        if flags.contains(.isImperialUnit) {
            self.unit = .imperial
        } else {
            self.unit = .si
        }

        if flags.contains(.timeStampPresent) {
            guard let timeStamp = DateTime(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self.timeStamp = timeStamp
        } else {
            self.timeStamp = nil
        }

        if flags.contains(.userIdPresent) {
            guard let userId = UInt8(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self.userId = userId
        } else {
            self.userId = nil
        }

        if flags.contains(.bmiAndHeightPresent) {
            guard let additionalInfo = AdditionalInfo(from: &byteBuffer, preferredEndianness: endianness) else {
                return nil
            }
            self.additionalInfo = additionalInfo
        } else {
            self.additionalInfo = nil
        }
    }

    public func encode(to byteBuffer: inout ByteBuffer, preferredEndianness endianness: Endianness) {
        var flags: Flags = []

        // write empty flags field for now to move writer index
        let flagsIndex = byteBuffer.writerIndex
        flags.encode(to: &byteBuffer, preferredEndianness: endianness)

        weight.encode(to: &byteBuffer, preferredEndianness: endianness)

        if let timeStamp {
            flags.insert(.timeStampPresent)
            timeStamp.encode(to: &byteBuffer, preferredEndianness: endianness)
        }

        if let userId {
            flags.insert(.userIdPresent)
            userId.encode(to: &byteBuffer, preferredEndianness: endianness)
        }

        if let additionalInfo {
            flags.insert(.bmiAndHeightPresent)
            additionalInfo.encode(to: &byteBuffer, preferredEndianness: endianness)
        }

        byteBuffer.setInteger(flags.rawValue, at: flagsIndex) // finally update the flags field
    }
}
