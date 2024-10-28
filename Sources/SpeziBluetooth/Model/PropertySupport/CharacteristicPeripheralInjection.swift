//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import ByteCoding
import CoreBluetooth
import SpeziFoundation


private protocol DecodableCharacteristic {
    @SpeziBluetooth
    func handleUpdateValueAssumingIsolation(_ data: Data?)
}

private protocol PrimitiveDecodableCharacteristic {
    func decodePrimitiveValue<ValueType>(from data: Data, as value: ValueType.Type) -> ValueType?
}


/// Captures and synchronizes access to the state of a ``Characteristic`` property wrapper.
@SpeziBluetooth
class CharacteristicPeripheralInjection<Value: Sendable>: Sendable {
    private let bluetooth: Bluetooth
    let peripheral: BluetoothPeripheral
    private let serviceId: BTUUID
    private let characteristicId: BTUUID

    private let state: Characteristic<Value>.State

    /// State support for control point characteristics.
    ///
    /// Fore more information see ``ControlPointCharacteristic``.
    private var controlPointTransaction: ControlPointTransaction<Value>?

    /// Manages the user supplied subscriptions to the value.
    private let subscriptions: ChangeSubscriptions<Value>
    /// We track all onChange closure registrations with `initial=false` to make sure to not call them with the initial value.
    /// The property is set to nil, once the initial value arrived.
    ///
    /// The initial value might only arrive later (e.g., only once the device is connected). Therefore, we need to keep track what handlers to call and which not while we are still waiting.
    private var nonInitialChangeHandlers: Set<UUID>? = [] // swiftlint:disable:this discouraged_optional_collection

    /// The registration object we received from the ``BluetoothPeripheral`` for our instance onChange handler.
    private var instanceRegistration: OnChangeRegistration?
    /// The registration object we received from the ``BluetoothPeripheral`` for our value onChange handler.
    private var valueRegistration: OnChangeRegistration?


    private var characteristic: GATTCharacteristic? {
        state.characteristic
    }


    init(
        bluetooth: Bluetooth,
        peripheral: BluetoothPeripheral,
        serviceId: BTUUID,
        characteristicId: BTUUID,
        state: Characteristic<Value>.State
    ) {
        self.bluetooth = bluetooth
        self.peripheral = peripheral
        self.serviceId = serviceId
        self.characteristicId = characteristicId
        self.state = state
        self.subscriptions = ChangeSubscriptions()
    }

    /// Setup the injection. Must be called after initialization to set up all handlers and write the initial value.
    /// - Parameter defaultNotify: Flag indicating if notification handlers should be registered immediately.
    func setup(defaultNotify: Bool) {
        registerCharacteristicInstanceChanges()

        guard self is DecodableCharacteristic else {
            return
        }
        // value is readable!

        // handle assigning the initial value!
        if let characteristic,
           let value = characteristic.value {
            handleUpdatedValue(value)
        }

        self.registerCharacteristicValueChanges()

        if defaultNotify {
            enableNotifications()
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

        // avoid accidentally inheriting any task local values
        Task.detached { @Sendable @SpeziBluetooth in
            await self.handleInitialCall(id: id, initial: initial, action: action)
        }
    }

    private func handleInitialCall(id: UUID, initial: Bool, action: (_ oldValue: Value, _ newValue: Value) async -> Void) async {
        if nonInitialChangeHandlers != nil {
            if !initial {
                nonInitialChangeHandlers?.insert(id)
            }
        } else if initial, let value = state.value {
            // nonInitialChangeHandlers is nil, meaning the initial value already arrived and we can call the action instantly if they wanted that
            subscriptions.notifySubscriber(id: id, with: value)
        }
    }

    /// Enable or disable notifications for the characteristic.
    /// - Parameter enabled: Flag indicating if notifications should be enabled.
    func enableNotifications(_ enabled: Bool = true) {
        peripheral.enableNotifications(enabled, serviceId: serviceId, characteristicId: characteristicId)
    }

    private func registerCharacteristicInstanceChanges() {
        self.instanceRegistration = peripheral.registerOnChangeCharacteristicHandler(
            service: serviceId,
            characteristic: characteristicId
        ) { [weak self] characteristic in
            self?.handleChangedCharacteristic(characteristic)
        }
    }

    private func registerCharacteristicValueChanges() {
        self.valueRegistration = peripheral.registerOnChangeHandler(service: serviceId, characteristic: characteristicId) { [weak self] data in
            self?.handleUpdatedValue(data)
        }
    }

    private func handleChangedCharacteristic(_ characteristic: GATTCharacteristic?) {
        // This the characteristic reference change?
        let instanceChanged = switch (self.characteristic, characteristic) {
        case let (.some(lhs), .some(rhs)):
            lhs.underlyingCharacteristic !== rhs.underlyingCharacteristic
        case (.some, .none):
            true
        case (.none, .some):
            true
        case (.none, .none):
            false
        }

        if self.characteristic != characteristic {
            state.characteristic = characteristic
        }

        if instanceChanged {
            if let characteristic {
                if let value = characteristic.value {
                    handleUpdatedValue(value)
                }
            } else {
                // we must make sure to not override the default value if one is present
                state.value = nil
            }
        }
    }

    private func handleUpdatedValue(_ data: Data?) {
        guard let decodable = self as? DecodableCharacteristic else {
            return
        }

        decodable.handleUpdateValueAssumingIsolation(data)
    }


    deinit {
        bluetooth.notifyDeviceDeinit(for: peripheral.id)
    }
}


extension CharacteristicPeripheralInjection: DecodableCharacteristic where Value: ByteDecodable {
    func handleUpdateValueAssumingIsolation(_ data: Data?) {
        if let data {
            guard let value = decodeValue(from: data) else {
                Bluetooth.logger.error("Could decode updated value for characteristic \(self.characteristic?.debugDescription ?? self.characteristicId.uuidString). Invalid format!")
                return
            }

            state.value = value
            self.fullFillControlPointRequest(value)

            // The first value is not always the initial value
            // e.g., error retrieving the initial value, or notify characteristics that don't support read!
            if let nonInitialChangeHandlers, peripheral.isReadingInitialValue(for: characteristicId, on: serviceId) {
                self.nonInitialChangeHandlers = nil
                self.subscriptions.notifySubscribers(with: value, ignoring: nonInitialChangeHandlers)
            } else {
                self.subscriptions.notifySubscribers(with: value)
            }
        } else {
            state.value = nil
        }
    }
}


extension CharacteristicPeripheralInjection: PrimitiveDecodableCharacteristic where Value: PrimitiveByteDecodable {
    fileprivate nonisolated func decodePrimitiveValue<ValueType>(from data: Data, as value: ValueType.Type) -> ValueType? {
        guard let value = Value(data: data, endianness: .little) as? ValueType else {
            preconditionFailure("Type \(Value.self) doesn't match requested \(ValueType.self).")
        }
        return value
    }
}


extension CharacteristicPeripheralInjection where Value: ByteDecodable {
    fileprivate func decodeValue(from data: Data) -> Value? {
        if let injection = self as? (any PrimitiveDecodableCharacteristic) {
            return injection.decodePrimitiveValue(from: data, as: Value.self)
        }
        return Value(data: data)
    }
}


extension CharacteristicPeripheralInjection where Value: ByteEncodable {
    fileprivate func encodeValue(_ value: Value) -> Data {
        if let primitiveValue = value as? PrimitiveByteEncodable {
            return primitiveValue.encode(endianness: .little)
        }
        return value.encode()
    }
}


// MARK: - Accessors Support

extension CharacteristicPeripheralInjection where Value: ByteDecodable {
    func read() async throws -> Value {
        guard let characteristic else {
            throw BluetoothError.notPresent(service: serviceId, characteristic: characteristicId)
        }

        let data = try await peripheral.read(characteristic: characteristic)
        guard let value = decodeValue(from: data) else {
            throw BluetoothError.incompatibleDataFormat
        }

        state.value = value // ensure we are consistent after returning
        return value
    }
}


extension CharacteristicPeripheralInjection where Value: ByteEncodable {
    func write(_ value: Value) async throws {
        guard let characteristic else {
            throw BluetoothError.notPresent(service: serviceId, characteristic: characteristicId)
        }

        let data = encodeValue(value)
        try await peripheral.write(data: data, for: characteristic)
        state.value = value
    }

    func writeWithoutResponse(_ value: Value) async throws {
        guard let characteristic else {
            throw BluetoothError.notPresent(service: serviceId, characteristic: characteristicId)
        }

        let data = encodeValue(value)
        await peripheral.writeWithoutResponse(data: data, for: characteristic)
        state.value = value
    }
}

// MARK: - Control Point Support

extension CharacteristicPeripheralInjection where Value: ControlPointCharacteristic {
    func sendRequest(_ value: Value, timeout: Duration = .seconds(20)) async throws -> Value {
        guard let characteristic else {
            throw BluetoothError.notPresent(service: serviceId, characteristic: characteristicId)
        }

        if !characteristic.isNotifying { // shortcut that doesn't require actor isolation.
            // It takes some time for the characteristic to acknowledge notification registration. Assuming the characteristic was injected
            // and notifications were requested, is good enough for us to assume we will receive the notification. Allows to send request much earlier.
            guard peripheral.didRequestNotifications(serviceId: serviceId, characteristicId: characteristicId) else {
                throw BluetoothError.controlPointRequiresNotifying(service: serviceId, characteristic: characteristicId)
            }
        }

        guard controlPointTransaction == nil else {
            throw BluetoothError.controlPointInProgress(service: serviceId, characteristic: characteristicId)
        }

        let transaction = ControlPointTransaction<Value>()
        self.controlPointTransaction = transaction

        defer {
            if controlPointTransaction?.id == transaction.id {
                controlPointTransaction = nil
            }
        }

        // make sure we are ready to receive the response
        async let response = controlPointContinuationTask(transaction)

        do {
            try await write(value)
        } catch {
            transaction.signalCancellation()
            _ = try? await response // await response to avoid cancellation
            
            throw error
        }
        
        async let _ = withTimeout(of: timeout) {
            await transaction.signalTimeout()
        }

        return try await response
    }

    private func controlPointContinuationTask(_ transaction: ControlPointTransaction<Value>) async throws -> Value {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                transaction.assignContinuation(continuation)
            }
        } onCancel: {
            Task { @SpeziBluetooth in
                transaction.signalCancellation()
            }
        }
    }
}


extension CharacteristicPeripheralInjection {
    fileprivate func fullFillControlPointRequest(_ value: Value) {
        if let controlPointTransaction {
            controlPointTransaction.fulfill(value)
            self.controlPointTransaction = nil
        }
    }
}
