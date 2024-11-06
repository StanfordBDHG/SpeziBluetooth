//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import CoreBluetooth
import Foundation
import SpeziFoundation


struct CharacteristicAccessorCapture: Sendable {
    let isNotifying: Bool
    let properties: CBCharacteristicProperties

    fileprivate init(isNotifying: Bool, properties: CBCharacteristicProperties) {
        self.isNotifying = isNotifying
        self.properties = properties
    }
}


struct GATTCharacteristicCapture: Sendable {
    let isNotifying: Bool
    let value: Data?
    let properties: CBCharacteristicProperties
    let descriptors: CBInstance<[CBDescriptor]>?

    init(from characteristic: CBCharacteristic) {
        self.isNotifying = characteristic.isNotifying
        self.value = characteristic.value
        self.properties = characteristic.properties
        self.descriptors = characteristic.descriptors.map { CBInstance(instantiatedOnDispatchQueue: $0) }
    }

    fileprivate init(from characteristic: borrowing GATTCharacteristic) {
        self.isNotifying = characteristic.isNotifying
        self.value = characteristic.value
        self.properties = characteristic.properties
        self.descriptors = characteristic.descriptors.map { CBInstance(unsafe: $0) }
    }
}


/// A Bluetooth characteristic of a service.
///
/// ## Topics
///
/// ### Instance Properties
/// - ``id``
/// - ``value``
/// - ``isNotifying``
/// - ``properties``
/// - ``descriptors``
/// - ``service``
@Observable
public final class GATTCharacteristic {
    let underlyingCharacteristic: CBCharacteristic

    /// The associated service if still available.
    public private(set) weak var service: GATTService?

    /// Whether the characteristic is currently notifying or not.
    public private(set) var isNotifying: Bool
    /// The value of the characteristic.
    public private(set) var value: Data?
    /// A list of the descriptors that have so far been discovered in this characteristic.
    public private(set) var descriptors: [CBDescriptor]? // swiftlint:disable:this discouraged_optional_collection

    /// The Bluetooth UUID of the characteristic.
    public var id: BTUUID {
        BTUUID(data: underlyingCharacteristic.uuid.data)
    }

    /// The properties of the characteristic.
    public var properties: CBCharacteristicProperties {
        underlyingCharacteristic.properties
    }

    private let captureLock = RWLock()

    var captured: CharacteristicAccessorCapture {
        access(keyPath: \.captured)
        return captureLock.withReadLock {
            CharacteristicAccessorCapture(isNotifying: _isNotifying, properties: properties)
        }
    }

    init(characteristic: CBCharacteristic, service: GATTService) {
        self.underlyingCharacteristic = characteristic
        self.service = service
        self.isNotifying = characteristic.isNotifying
        self.value = characteristic.value
        self.descriptors = characteristic.descriptors
    }


    @SpeziBluetooth
    func synchronizeModel(capture: GATTCharacteristicCapture) {
        var shouldNotifyCapture = false

        if capture.isNotifying != isNotifying {
            shouldNotifyCapture = true
            withMutation(keyPath: \.isNotifying) {
                captureLock.withWriteLock {
                    _isNotifying = capture.isNotifying
                }
            }
        }
        if capture.value != value {
            withMutation(keyPath: \.value) {
                captureLock.withWriteLock {
                    _value = capture.value
                }
            }
        }
        if capture.descriptors?.cbObject != descriptors {
            withMutation(keyPath: \.descriptors) {
                captureLock.withWriteLock {
                    _descriptors = capture.descriptors?.cbObject
                }
            }
        }

        if shouldNotifyCapture {
            Task { @MainActor in
                self.withMutation(keyPath: \.captured) {}
            }
        }
    }
}


extension GATTCharacteristic {}


extension GATTCharacteristic: Identifiable {}


extension GATTCharacteristic: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        "Characteristic(id: \(id), properties: \(properties), \(value.map { "value: \($0), " } ?? "")isNotifying, \(isNotifying))"
    }

    public var debugDescription: String {
        description
    }
}


extension GATTCharacteristic: Hashable {
    public static func == (lhs: GATTCharacteristic, rhs: GATTCharacteristic) -> Bool {
        lhs.underlyingCharacteristic == rhs.underlyingCharacteristic
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(underlyingCharacteristic)
    }
}
