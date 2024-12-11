//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2024 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Atomics
import Foundation
import SpeziFoundation


/// A dedicated, observable storage container for a ``BluetoothPeripheral``.
///
/// Main motivation is to have `BluetoothPeripheral` be implemented as an actor and moving state
/// into a separate state container that is `@Observable`.
@Observable
final class PeripheralStorage: ValueObservable, Sendable {
    private let _state: ManagedAtomicMainActorBuffered<PeripheralState>
    private let _rssi: ManagedAtomicMainActorBuffered<Int>
    private let _nearby: ManagedAtomicMainActorBuffered<Bool>
    private let _lastActivityTimeIntervalSince1970BitPattern: ManagedAtomic<UInt64> // workaround to store store Date atomically
    // swiftlint:disable:previous identifier_name

    private let _peripheralName: MainActorBuffered<String?>
    private let _advertisementData: MainActorBuffered<AdvertisementData>
    // Its fine to have a single lock. Readers will be isolated anyways to the SpeziBluetooth global actor.
    // The only side-effect is, that readers will wait for any write to complete, which is fine as peripheralName is rarely updated.
    private let lock = RWLock()

    @SpeziBluetooth var lastActivity: Date {
        didSet {
            _lastActivityTimeIntervalSince1970BitPattern.store(lastActivity.timeIntervalSince1970.bitPattern, ordering: .relaxed)
            _$simpleRegistrar.triggerDidChange(for: \.lastActivity, on: self)
        }
    }


    @SpeziBluetooth var services: [BTUUID: GATTService]? { // swiftlint:disable:this discouraged_optional_collection
        didSet {
            _$simpleRegistrar.triggerDidChange(for: \.services, on: self)
        }
    }

    @inlinable var name: String? {
        access(keyPath: \._peripheralName)
        access(keyPath: \._advertisementData)

        return lock.withReadLock {
            _peripheralName.loadUnsafe() ?? _advertisementData.loadUnsafe().localName
        }
    }

    @inlinable var readOnlyRssi: Int {
        access(keyPath: \._rssi)
        return _rssi.load(ordering: .relaxed)
    }

    @inlinable var readOnlyState: PeripheralState {
        access(keyPath: \._state)
        return _state.load(ordering: .relaxed)
    }

    @inlinable var readOnlyNearby: Bool {
        access(keyPath: \._nearby)
        return _nearby.load(ordering: .relaxed)
    }

    @inlinable var readOnlyAdvertisementData: AdvertisementData {
        access(keyPath: \._advertisementData)
        return _advertisementData.load(using: lock)
    }

    var readOnlyLastActivity: Date {
        let timeIntervalSince1970 = Double(bitPattern: _lastActivityTimeIntervalSince1970BitPattern.load(ordering: .relaxed))
        return Date(timeIntervalSince1970: timeIntervalSince1970)
    }

    @SpeziBluetooth var peripheralName: String? {
        get {
            access(keyPath: \._peripheralName)
            return _peripheralName.load(using: lock)
        }
        set {
            let didChange = _peripheralName.storeAndCompare(newValue, using: lock) { @Sendable mutation in
                self.withMutation(keyPath: \._peripheralName, mutation)
            }

            if didChange {
                _$simpleRegistrar.triggerDidChange(for: \.peripheralName, on: self)
            }
        }
    }

    @SpeziBluetooth var rssi: Int {
        get {
            readOnlyRssi
        }
        set {
            let didChange = _rssi.storeAndCompare(newValue) { @Sendable mutation in
                self.withMutation(keyPath: \._rssi, mutation)
            }
            if didChange {
                _$simpleRegistrar.triggerDidChange(for: \.rssi, on: self)
            }
        }
    }

    @SpeziBluetooth var advertisementData: AdvertisementData {
        get {
            readOnlyAdvertisementData
        }
        set {
            let didChange = _advertisementData.storeAndCompare(newValue, using: lock) { @Sendable mutation in
                self.withMutation(keyPath: \._advertisementData, mutation)
            }

            if didChange {
                _$simpleRegistrar.triggerDidChange(for: \.advertisementData, on: self)
            }
        }
    }

    @SpeziBluetooth var state: PeripheralState {
        get {
            readOnlyState
        }
        set {
            let didChange = _state.storeAndCompare(newValue) { @Sendable mutation in
                self.withMutation(keyPath: \._state, mutation)
            }

            if didChange {
                _$simpleRegistrar.triggerDidChange(for: \.state, on: self)
            }
        }
    }

    @SpeziBluetooth var nearby: Bool {
        get {
            readOnlyNearby
        }
        set {
            let didChange = _nearby.storeAndCompare(newValue) { @Sendable mutation in
                self.withMutation(keyPath: \._nearby, mutation)
            }

            if didChange {
                _$simpleRegistrar.triggerDidChange(for: \.nearby, on: self)
            }
        }
    }

    // swiftlint:disable:next identifier_name
    @ObservationIgnored let _$simpleRegistrar = ValueObservationRegistrar<PeripheralStorage>()

    init(peripheralName: String?, rssi: Int, advertisementData: AdvertisementData, state: PeripheralState, lastActivity: Date = .now) {
        self._peripheralName = MainActorBuffered(peripheralName)
        self._advertisementData = MainActorBuffered(advertisementData)
        self._rssi = ManagedAtomicMainActorBuffered(rssi)
        self._state = ManagedAtomicMainActorBuffered(state)
        self._nearby = ManagedAtomicMainActorBuffered(false)
        self._lastActivity = lastActivity
        self._lastActivityTimeIntervalSince1970BitPattern = ManagedAtomic(lastActivity.timeIntervalSince1970.bitPattern)
    }

    @SpeziBluetooth
    func update(state: PeripheralState) {
        let current = self.state
        switch (current, state) {
        case (.connecting, .connected):
            // we set the connected state transition on our own! See `signalFullyDiscovered`
            break
        default:
            self.state = state
        }

        if current == .connecting || current == .connected {
            self.nearby = true
        }
    }

    @SpeziBluetooth
    func signalFullyDiscovered() {
        if state == .connecting {
            state = .connected
            update(state: .connected) // ensure other logic is called as well
        }
    }
}
