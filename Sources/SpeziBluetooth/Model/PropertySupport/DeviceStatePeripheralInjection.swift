//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Foundation


@SpeziBluetooth
class DeviceStatePeripheralInjection<Value: Sendable>: Sendable {
    private let bluetooth: Bluetooth
    private let peripheral: BluetoothPeripheral
    private let accessKeyPath: KeyPath<BluetoothPeripheral, Value> & Sendable
    private let observationKeyPath: KeyPath<PeripheralStorage, Value>?
    private let subscriptions: ChangeSubscriptions<Value>

    nonisolated var value: Value {
        peripheral[keyPath: accessKeyPath]
    }


    init(bluetooth: Bluetooth, peripheral: BluetoothPeripheral, keyPath: KeyPath<BluetoothPeripheral, Value> & Sendable) {
        self.bluetooth = bluetooth
        self.peripheral = peripheral
        self.accessKeyPath = keyPath
        self.observationKeyPath = keyPath.storageEquivalent()
        self.subscriptions = ChangeSubscriptions()
    }

    func setup() {
        trackStateUpdate()
    }

    private func trackStateUpdate() {
        guard let observationKeyPath else {
            return
        }

        peripheral.onChange(of: observationKeyPath) { [weak self] value in
            guard let self = self else {
                return
            }

            self.trackStateUpdate()
            self.subscriptions.notifySubscribers(with: value)
        }
    }

    nonisolated func newSubscription() -> AsyncStream<Value> {
        subscriptions.newSubscription()
    }

    nonisolated func newOnChangeSubscription(
        initial: Bool,
        perform action: @escaping @Sendable (_ oldValue: Value, _ newValue: Value) async -> Void
    ) {
        let id = subscriptions.newOnChangeSubscription(perform: action)

        if initial {
            let value = peripheral[keyPath: accessKeyPath]
            subscriptions.notifySubscriber(id: id, with: value)
        }
    }

    deinit {
        bluetooth.notifyDeviceDeinit(for: peripheral.id)
    }
}


extension KeyPath where Root == BluetoothPeripheral {
    // swiftlint:disable:next cyclomatic_complexity
    func storageEquivalent() -> KeyPath<PeripheralStorage, Value>? {
        let anyKeyPath: AnyKeyPath? = switch self {
        case \.name:
            \PeripheralStorage.name
        case \.localName:
            \PeripheralStorage._localName
        case \.rssi:
            \PeripheralStorage._rssi
        case \.advertisementData:
            \PeripheralStorage._advertisementData
        case \.state:
            \PeripheralStorage._state
        case \.services:
            \PeripheralStorage._services
        case \.nearby:
            \PeripheralStorage._nearby
        case \.lastActivity:
            \PeripheralStorage._lastActivity
        case \.id:
            nil
        default:
            preconditionFailure("Could not find a observable translation for peripheral KeyPath \(self)")
        }

        guard let anyKeyPath else {
            return nil
        }

        guard let keyPath = anyKeyPath as? KeyPath<PeripheralStorage, Value> else {
            preconditionFailure("Failed to cast KeyPath \(anyKeyPath) to \(KeyPath<PeripheralStorage, Value>.self)")
        }

        return keyPath
    }
}
