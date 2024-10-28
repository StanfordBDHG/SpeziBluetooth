//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Atomics
import ByteCoding
import CoreBluetooth
import Foundation


/// Declare a characteristic within a Bluetooth service.
///
/// This property wrapper can be used to declare a Bluetooth characteristic within a ``BluetoothService``.
/// The value type of your property needs to be optional and conform to
/// [`ByteEncodable`](https://swiftpackageindex.com/stanfordspezi/spezifileformats/documentation/bytecoding/byteencodable),
/// [`ByteDecodable`](https://swiftpackageindex.com/stanfordspezi/spezifileformats/1.0.0/documentation/bytecoding/bytedecodable) or
/// [`ByteCodable`](https://swiftpackageindex.com/stanfordspezi/spezifileformats/documentation/bytecoding/bytecodable) respectively.
///
/// If your device is connected, the characteristic value is automatically updated upon a characteristic read or a notify.
///
/// - Note: Every `Characteristic` is [Observable](https://developer.apple.com/documentation/Observation) out of the box.
///     You can easily use the characteristic value within your SwiftUI view and the view will be automatically re-rendered
///     when the characteristic value is updated.
///
/// The below code example demonstrates declaring the Firmware Revision characteristic of the Device Information service.
///
/// ```swift
/// struct DeviceInformationService: BluetoothService {
///    static let id: BTUUID = "180A"
///
///     @Characteristic(id: "2A26")
///     var firmwareRevision: String?
/// }
/// ```
///
/// ### Automatic Notifications
///
/// If your characteristic supports notifications, you can automatically subscribe to characteristic notifications
/// by supplying the `notify` initializer argument.
///
/// - Tip: If you want to react to every change of the characteristic value, you can use
///     ``CharacteristicAccessor/onChange(initial:perform:)-4ecct`` or
///     ``CharacteristicAccessor/onChange(initial:perform:)-6ahtp``  to set up your action.
///
/// The below code example uses the [Bluetooth Heart Rate Service](https://www.bluetooth.com/specifications/specs/heart-rate-service-1-0)
/// to demonstrate the automatic notifications feature for the Heart Rate Measurement characteristic.
///
/// - Important: This closure is called from the ``SpeziBluetooth/SpeziBluetooth`` global actor, if you don't pass in an async method
///     that has an annotated actor isolation (e.g., `@MainActor` or actor isolated methods).
///
/// ```swift
/// struct HeartRateService: BluetoothService {
///     static let id: BTUUID = "180D"
///
///     @Characteristic(id: "2A37", notify: true)
///     var heartRateMeasurement: HeartRateMeasurement?
///
///     init() {}
///
///     configure() {
///         $heartRateMeasurement.onChange { [weak self] value in
///             self?.processMeasurement(measurement)
///         }
///     }
///
///     func processMeasurement(_ measurement: HeartRateMeasurement) {
///         // process measurements ...
///     }
/// }
/// ```
///
/// ### Characteristic Interactions
///
/// To interact with a characteristic to read or write a value or enable or disable notifications,
/// you can use the ``projectedValue`` (`$` notation) to retrieve a temporary ``CharacteristicAccessor`` instance.
///
/// Do demonstrate this functionality, we completed the implementation of our Heart Rate Service
/// according to its [Specification](https://www.bluetooth.com/specifications/specs/heart-rate-service-1-0).
/// The example demonstrates reading and writing of characteristic values, controlling characteristic notifications,
/// and inspecting other properties like `isPresent`.
///
/// ```swift
/// struct HeartRateService: BluetoothService {
///    static let id: BTUUID = "180D"
///
///     @Characteristic(id: "2A37", notify: true)
///     var heartRateMeasurement: HeartRateMeasurement?
///     @Characteristic(id: "2A38")
///     var bodySensorLocation: UInt8?
///     @Characteristic(id: "2A39")
///     var heartRateControlPoint: UInt8?
///
///     var measurementsRunning: Bool {
///         $heartRateMeasurement.isNotifying
///     }
///
///     var energyExpendedFeatureSupported: Bool {
///         // characteristic is required to be present if feature is supported (see Heart Rate Service spec).
///         $heartRateControlPoint.isPresent
///     }
///
///
///     init() {}
///
///
///     func handleConnected() async throws { // manually called from the outside
///         try await $bodySensorLocation.read()
///         if energyExpendedFeatureSupported {
///             try await $heartRateControlPoint.write(0x01) // resets the energy expended measurement
///         }
///     }
///
///     func pauseMeasurements() async {
///         await $heartRateMeasurement.enableNotifications(false)
///     }
///
///     func resumeMeasurements() async {
///         await $heartRateMeasurement.enableNotifications()
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Declaring a Characteristic
/// - ``init(wrappedValue:id:autoRead:)``
/// - ``init(wrappedValue:id:notify:autoRead:)-9medy``
/// - ``init(wrappedValue:id:notify:autoRead:)-9f2nr``
///
/// ### Inspecting a Characteristic
/// - ``CharacteristicAccessor/isPresent``
/// - ``CharacteristicAccessor/properties``
///
/// ### Reading a value
/// - ``CharacteristicAccessor/read()``
///
/// ### Writing a value
/// - ``CharacteristicAccessor/write(_:)``
/// - ``CharacteristicAccessor/writeWithoutResponse(_:)``
///
/// ### Controlling notifications
/// - ``CharacteristicAccessor/isNotifying``
/// - ``CharacteristicAccessor/enableNotifications(_:)``
///
/// ### Get notified about changes
/// - ``CharacteristicAccessor/onChange(initial:perform:)-4ecct``
/// - ``CharacteristicAccessor/onChange(initial:perform:)-6ahtp``
///
/// ### Control Point Characteristics
/// - ``ControlPointCharacteristic``
/// - ``CharacteristicAccessor/sendRequest(_:timeout:)``
///
/// ### Property wrapper access
/// - ``wrappedValue``
/// - ``projectedValue``
/// - ``CharacteristicAccessor``
@propertyWrapper
public struct Characteristic<Value: Sendable>: Sendable {
    /// Storage unit for the property wrapper.
    final class Storage: Sendable {
        enum DefaultNotifyState: UInt8, AtomicValue {
            case disabled
            case enabled
            case collectedDisabled
            case collectedEnabled

            var defaultNotify: Bool {
                switch self {
                case .disabled, .collectedDisabled:
                    return false
                case .enabled, .collectedEnabled:
                    return true
                }
            }

            var completed: Bool {
                switch self {
                case .disabled, .enabled:
                    false
                case .collectedDisabled, .collectedEnabled:
                    true
                }
            }

            init(from defaultNotify: Bool) {
                self = defaultNotify ? .enabled : .disabled
            }

            static func collected(notify: Bool) -> DefaultNotifyState {
                notify ? .collectedEnabled : .collectedDisabled
            }
        }

        let id: BTUUID
        let defaultNotify: ManagedAtomic<DefaultNotifyState>
        let autoRead: ManagedAtomic<Bool>

        let injection = ManagedAtomicLazyReference<CharacteristicPeripheralInjection<Value>>()
        let testInjections = ManagedAtomicLazyReference<CharacteristicTestInjections<Value>>()

        let state: State

        init(id: BTUUID, defaultNotify: Bool, autoRead: Bool, initialValue: Value?) {
            self.id = id
            self.defaultNotify = ManagedAtomic(DefaultNotifyState(from: defaultNotify))
            self.autoRead = ManagedAtomic(autoRead)
            self.state = State(initialValue: initialValue)
        }
    }

    @Observable
    final class State: Sendable {
        struct CharacteristicCaptureRetrieval: Sendable { // workaround to make the retrieval of the `capture` property Sendable
            private nonisolated(unsafe) let characteristic: GATTCharacteristic

            var capture: GATTCharacteristicCapture {
                characteristic.captured
            }

            init(_ characteristic: GATTCharacteristic) {
                self.characteristic = characteristic
            }
        }

        private let _value: MainActorBuffered<Value?>
        @ObservationIgnored private nonisolated(unsafe) var _capture: CharacteristicCaptureRetrieval?
        // protects both properties above
        private let lock = RWLock()

        @SpeziBluetooth @ObservationIgnored  var characteristic: GATTCharacteristic? {
            didSet {
                lock.withWriteLock {
                    _capture = characteristic.map { CharacteristicCaptureRetrieval($0) }
                }
            }
        }

        @inlinable var readOnlyValue: Value? {
            access(keyPath: \._value)
            return _value.load(using: lock)
        }

        var capture: GATTCharacteristicCapture? {
            let characteristic = lock.withReadLock {
                _capture
            }
            return characteristic?.capture
        }

        @SpeziBluetooth var value: Value? {
            get {
                readOnlyValue
            }
            set {
                inject(newValue)
            }
        }

        init(initialValue: Value?) {
            self._value = MainActorBuffered(initialValue)
        }

        @inlinable
        func inject(_ value: Value?) {
            _value.store(value, using: lock) { @Sendable mutation in
                self.withMutation(keyPath: \._value, mutation)
            }
        }
    }

    private let storage: Storage

    /// The characteristic description.
    var description: CharacteristicDescription {
        CharacteristicDescription(id: storage.id, discoverDescriptors: false, autoRead: storage.autoRead.load(ordering: .relaxed))
    }

    /// Access the current characteristic value.
    ///
    /// This is either the last read value or the latest notified value.
    public var wrappedValue: Value? {
        storage.state.readOnlyValue
    }

    /// Retrieve a temporary accessors instance.
    ///
    /// This type allows you to interact with a Characteristic.
    ///
    /// - Note: The accessor captures the characteristic instance upon creation. Within the same `CharacteristicAccessor` instance
    ///     the view on the characteristic is consistent (characteristic exists vs. it doesn't, the underlying values themselves might still change).
    ///     However, if you project a new `CharacteristicAccessor` instance right after your access,
    ///     the view on the characteristic might have changed due to the asynchronous nature of SpeziBluetooth.
    public var projectedValue: CharacteristicAccessor<Value> {
        CharacteristicAccessor(storage)
    }

    fileprivate init(wrappedValue: Value? = nil, characteristic: BTUUID, notify: Bool, autoRead: Bool = true) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.storage = Storage(id: characteristic, defaultNotify: notify, autoRead: autoRead, initialValue: wrappedValue)
    }


    @SpeziBluetooth
    func inject(bluetooth: Bluetooth, peripheral: BluetoothPeripheral, serviceId: BTUUID, service: GATTService?) {
        let injection = storage.injection.storeIfNilThenLoad(CharacteristicPeripheralInjection<Value>(
            bluetooth: bluetooth,
            peripheral: peripheral,
            serviceId: serviceId,
            characteristicId: storage.id,
            state: storage.state
        ))
        assert(injection.peripheral === peripheral, "\(#function) cannot be called more than once in the lifetime of a \(Self.self) instance")

        storage.state.characteristic = service?.getCharacteristic(id: storage.id)

#if compiler(<6)
        var defaultNotify: Bool = false
#else
        let defaultNotify: Bool
#endif
        while true {
            let notifyState = storage.defaultNotify.load(ordering: .acquiring)
            let notify = notifyState.defaultNotify

            let (exchanged, _) = storage.defaultNotify.compareExchange(
                expected: notifyState,
                desired: .collected(notify: notify),
                ordering: .acquiringAndReleasing
            )
            if exchanged {
                defaultNotify = notify
                break
            }
        }

        injection.setup(defaultNotify: defaultNotify)
    }
}


extension Characteristic where Value: ByteEncodable {
    /// Declare a write-only characteristic.
    /// - Parameters:
    ///   - wrappedValue: An optional default value.
    ///   - id: The characteristic id.
    ///   - autoRead: Flag indicating if  the initial value should be automatically read from the peripheral.
    public init(wrappedValue: Value? = nil, id: BTUUID, autoRead: Bool = true) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.init(wrappedValue: wrappedValue, characteristic: id, notify: false, autoRead: autoRead)
    }
}


extension Characteristic where Value: ByteDecodable {
    /// Declare a read-only characteristic.
    /// - Parameters:
    ///   - wrappedValue: An optional default value.
    ///   - id: The characteristic id.
    ///   - notify: Automatically subscribe to characteristic notifications if supported.
    ///   - autoRead: Flag indicating if  the initial value should be automatically read from the peripheral.
    public init(wrappedValue: Value? = nil, id: BTUUID, notify: Bool = false, autoRead: Bool = true) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.init(wrappedValue: wrappedValue, characteristic: id, notify: notify, autoRead: autoRead)
    }
}


extension Characteristic where Value: ByteCodable { // reduce ambiguity
    /// Declare a read and write characteristic.
    /// - Parameters:
    ///   - wrappedValue: An optional default value.
    ///   - id: The characteristic id.
    ///   - notify: Automatically subscribe to characteristic notifications if supported.
    ///   - autoRead: Flag indicating if  the initial value should be automatically read from the peripheral.
    public init(wrappedValue: Value? = nil, id: BTUUID, notify: Bool = false, autoRead: Bool = true) {
        // swiftlint:disable:previous function_default_parameter_at_end
        self.init(wrappedValue: wrappedValue, characteristic: id, notify: notify, autoRead: autoRead)
    }
}


extension Characteristic: ServiceVisitable {
    func accept<Visitor: ServiceVisitor>(_ visitor: inout Visitor) {
        visitor.visit(self)
    }
}
