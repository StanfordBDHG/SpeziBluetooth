//
// This source file is part of the Stanford Spezi open-source project
//
// SPDX-FileCopyrightText: 2023 Stanford University and the project authors (see CONTRIBUTORS.md)
//
// SPDX-License-Identifier: MIT
//

import Atomics
import CoreBluetooth


/// Declare a service within a Bluetooth device.
///
/// This property wrapper can be used to declare a Bluetooth service within a ``BluetoothDevice``.
/// You must provide an instance to your ``BluetoothService`` implementation.
/// Refer to the respective documentation for more details.
///
/// Below is a short code example on how you would declare your [Bluetooth Heart Rate Service](https://www.bluetooth.com/specifications/specs/heart-rate-service-1-0)
/// implementation within your Bluetooth device.
/// 
/// ```swift
/// class MyDevice: BluetoothDevice {
///     @Service var heartRate = HeartRateService()
/// }
/// ```
///
/// ## Topics
///
/// ### Declaring a Service
/// - ``init(wrappedValue:)``
///
/// ### Inspecting a Service
/// - ``ServiceAccessor/isPresent``
/// - ``ServiceAccessor/isPrimary``
///
/// ### Property wrapper access
/// - ``wrappedValue``
/// - ``projectedValue``
/// - ``ServiceAccessor``
@propertyWrapper
public struct Service<S: BluetoothService> {
    final class Storage: Sendable {
        let injection = ManagedAtomicLazyReference<ServicePeripheralInjection<S>>()
        let state = State()
    }

    @Observable
    final class State: Sendable {
        // Type safe capture of the current GATTService state.
        // To make this lock-free and non-blocking, we collapse the information we need in `ServiceAccessor` into a single
        // RawRepresentable atomic value.
        enum ServiceState: UInt8, RawRepresentable, AtomicValue {
            case notPresent
            case presentNotPrimary
            case presentPrimary

            @SpeziBluetooth
            init(from value: GATTService?) {
                switch value {
                case .none:
                    self = .notPresent
                case let .some(service):
                    self = service.isPrimary ? .presentPrimary : .presentNotPrimary
                }
            }
        }

        private let _serviceState = ManagedAtomicMainActorBuffered<ServiceState>(.notPresent)

        var serviceState: ServiceState {
            get {
                access(keyPath: \.serviceState)
                return _serviceState.load(ordering: .relaxed)
            }
            set {
                _serviceState.store(newValue) { @Sendable mutation in
                    self.withMutation(keyPath: \.serviceState, mutation)
                }
            }
        }

        init() {}
    }

    var id: BTUUID {
        S.id
    }

    private let storage = Storage()

    /// Access the service instance.
    public let wrappedValue: S

    /// Retrieve a temporary accessors instance.
    ///
    /// This type allows you to interact with a Service's properties.
    ///
    /// - Note: The accessor captures the service instance upon creation. Within the same `ServiceAccessor` instance
    ///     the view on the service is consistent. However, if you project a new `ServiceAccessor` instance right
    ///     after your access, the view on the service might have changed due to the asynchronous nature of SpeziBluetooth.
    public var projectedValue: ServiceAccessor<S> {
        ServiceAccessor(storage)
    }

    /// Declare a service.
    /// - Parameters:
    ///   - wrappedValue: The service instance.
    public init(wrappedValue: S) {
        self.wrappedValue = wrappedValue
    }


    @SpeziBluetooth
    func inject(bluetooth: Bluetooth, peripheral: BluetoothPeripheral, service: GATTService?) {
        let injection = storage.injection.storeIfNilThenLoad(
            ServicePeripheralInjection(bluetooth: bluetooth, peripheral: peripheral, serviceId: id, service: service, state: storage.state)
        )
        assert(injection.peripheral === peripheral, "\(#function) cannot be called more than once in the lifetime of a \(Self.self) instance")

        injection.setup()
    }
}


extension Service: Sendable where S: Sendable {}


extension Service: DeviceVisitable {
    func accept<Visitor: DeviceVisitor>(_ visitor: inout Visitor) {
        visitor.visit(self)
    }
}
